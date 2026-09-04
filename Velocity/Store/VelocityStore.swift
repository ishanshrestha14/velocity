import AppKit
import Foundation
import Observation

/// The single source of truth for application state.
///
/// Views read from this and call its methods; they never mutate state directly
/// and never contain aggregation, Git, or persistence logic. Every mutation
/// schedules a save, so durability is not something callers have to remember.
@MainActor
@Observable
final class VelocityStore {
    // MARK: - Persisted state

    private(set) var shippedItems: [ShippedItem] = []
    private(set) var repositories: [Repository] = []
    var settings: VelocitySettings = .default {
        didSet {
            scheduleSaveIfLoaded()
            if hasLoaded,
               oldValue.isBackgroundScanningEnabled != settings.isBackgroundScanningEnabled
                   || oldValue.scanIntervalMinutes != settings.scanIntervalMinutes {
                restartBackgroundScanning()
            }
        }
    }

    // MARK: - View state (never persisted)

    /// Dashboard scope filter. Analytics-only: it never alters stored data.
    var scopeFilter: ScopeFilter = .all

    /// Day of the current month shown by the dashboard's month-inspection
    /// slider. View state only — it never alters stored data, and defaults to
    /// today so the dashboard opens showing the most recent progress.
    var inspectedDay: Int = Calendar.current.component(.day, from: .now)

    /// Set when loading or saving failed. The UI surfaces this rather than
    /// letting a data problem pass unnoticed.
    private(set) var persistenceError: PersistenceError?

    /// False until `load()` finishes. Nothing is written before then, so a slow
    /// or failed load can never overwrite good data with an empty document.
    private(set) var hasLoaded = false

    /// True while a scan is running. The UI disables re-scanning rather than
    /// queueing a second one.
    private(set) var isScanning = false

    /// The most recent scan. Not persisted — it describes one run, and a stale
    /// report from a previous launch would be misleading.
    private(set) var lastScanReport: ScanReport?

    /// Set when a scan could not start at all, as opposed to a single
    /// repository failing inside one.
    private(set) var scanError: GitError?

    /// How many items the last scan added to the feed.
    private(set) var lastImportCount = 0

    // MARK: - Dependencies

    private let persistence: PersistenceService?
    private let scanner: GitScanner?
    private let scoringEngine = ScoringEngine()
    private var saveTask: Task<Void, Never>?

    /// How long to wait after a change before writing. Collapses a burst of
    /// edits — or a scan importing many commits — into one write.
    private let saveDebounce = Duration.milliseconds(400)

    // MARK: - Init

    init(
        persistence: PersistenceService? = nil,
        scanner: GitScanner? = nil,
        data: VelocityData = .empty,
        startupError: PersistenceError? = nil
    ) {
        self.persistence = persistence
        self.scanner = scanner
        self.persistenceError = startupError
        applyLoaded(data)
    }

    // MARK: - Snapshot

    /// The full state as a serializable document.
    var snapshot: VelocityData {
        VelocityData(items: shippedItems, repositories: repositories, settings: settings)
    }

    /// Replace all state with a loaded document without triggering a save.
    private func applyLoaded(_ data: VelocityData) {
        shippedItems = data.items.sorted { $0.timestamp > $1.timestamp }
        repositories = data.repositories
        let wasLoaded = hasLoaded
        hasLoaded = false        // suppress the didSet on settings
        settings = data.settings
        hasLoaded = wasLoaded
    }

    // MARK: - Loading

    /// Read stored state from disk. Called once at launch.
    func load() async {
        if let persistence {
            let result = await persistence.load()
            applyLoaded(result.data)
            persistenceError = result.error
        }
        hasLoaded = true

        if canScan { await scanRepositories() }
        restartBackgroundScanning()
    }

    func dismissPersistenceError() {
        persistenceError = nil
    }

    /// Where the data lives, for the settings screen to show and reveal.
    var dataDirectoryURL: URL? {
        persistence?.rootDirectoryURL
    }

    /// Open the data folder in Finder. The files are plain JSON and the user is
    /// meant to be able to go and read them.
    func revealDataDirectory() {
        guard let dataDirectoryURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([dataDirectoryURL])
    }

    // MARK: - Export

    /// Write the current state to a file the user chose, independent of
    /// where Velocity's own data lives. A standalone copy for backup or
    /// sharing, not something the debounced autosave path touches.
    func export(to url: URL) async throws {
        guard let persistence else {
            throw PersistenceError.writeFailed("Export is unavailable without a data folder.")
        }
        try await persistence.export(snapshot, to: url)
    }

    // MARK: - Saving

    private func scheduleSaveIfLoaded() {
        guard hasLoaded else { return }
        scheduleSave()
    }

    private func scheduleSave() {
        guard let persistence else { return }
        saveTask?.cancel()
        let data = snapshot
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: self?.saveDebounce ?? .milliseconds(400))
            guard !Task.isCancelled else { return }
            do {
                try await persistence.save(data)
                self?.persistenceError = nil
            } catch let error as PersistenceError {
                self?.persistenceError = error
            } catch {
                self?.persistenceError = .writeFailed(error.localizedDescription)
            }
        }
    }

    /// Write immediately rather than waiting out the debounce.
    ///
    /// Quitting cannot wait for an async save, so this one is synchronous: a
    /// change made a moment before quit still reaches disk.
    func flushPendingSave() {
        guard let persistence, hasLoaded else { return }
        saveTask?.cancel()
        saveTask = nil
        try? persistence.writeSynchronously(snapshot)
    }

    // MARK: - Shipped items

    /// Insert an item, keeping the feed newest-first.
    ///
    /// Items are keyed by `id` — the Git SHA for Git-derived shipments — so
    /// re-adding the same commit updates it in place instead of duplicating it.
    func add(_ item: ShippedItem) {
        add(contentsOf: [item])
    }

    /// Insert many items at once, deduplicating by id.
    func add(contentsOf items: [ShippedItem]) {
        guard !items.isEmpty else { return }
        for item in items {
            if let existing = shippedItems.firstIndex(where: { $0.id == item.id }) {
                shippedItems[existing] = item
            } else {
                shippedItems.append(item)
            }
        }
        shippedItems.sort { $0.timestamp > $1.timestamp }
        scheduleSaveIfLoaded()
    }

    /// Record work by hand, for what Git did not capture.
    @discardableResult
    func logManualItem(title: String, scope: ProjectScope, weight: ImpactWeight) -> ShippedItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let item = ShippedItem.manual(title: trimmed, scope: scope, weight: weight)
        add(item)
        return item
    }

    /// Change an item's impact after the fact — for a manual entry logged in
    /// haste, or a commit whose message undersells what it did.
    func setWeight(_ weight: ImpactWeight, forItemWith id: ShippedItem.ID) {
        guard let index = shippedItems.firstIndex(where: { $0.id == id }),
              shippedItems[index].weight != weight
        else { return }
        shippedItems[index].weight = weight
        scheduleSaveIfLoaded()
    }

    /// Move an item between work and personal.
    func setScope(_ scope: ProjectScope, forItemWith id: ShippedItem.ID) {
        guard let index = shippedItems.firstIndex(where: { $0.id == id }),
              shippedItems[index].scope != scope
        else { return }
        shippedItems[index].scope = scope
        scheduleSaveIfLoaded()
    }

    func delete(id: ShippedItem.ID) {
        let before = shippedItems.count
        shippedItems.removeAll { $0.id == id }
        guard shippedItems.count != before else { return }
        scheduleSaveIfLoaded()
    }

    // MARK: - Repositories

    /// What happened to one path handed to `addRepository`.
    ///
    /// Adding several folders at once means some can succeed while others are
    /// duplicates, so "did nothing" and "added it" have to be told apart.
    enum AddOutcome: Equatable, Sendable {
        case added(Repository)
        case alreadyPresent
    }

    /// Add a repository after checking it is one.
    ///
    /// Throws rather than silently ignoring a bad path, so the settings screen
    /// can say what is actually wrong with the folder the user picked.
    @discardableResult
    func addRepository(path: String, scope: ProjectScope) async throws -> AddOutcome {
        let cleanPath = (path as NSString).standardizingPath
        guard !repositories.contains(where: { $0.path == cleanPath }) else {
            return .alreadyPresent
        }

        if let scanner {
            try await GitRepositoryValidator(runner: scanner.runner).validate(path: cleanPath)
        }

        let repository = Repository(
            name: GitRepositoryValidator.suggestedName(for: cleanPath),
            path: cleanPath,
            scope: scope
        )
        repositories.append(repository)
        scheduleSaveIfLoaded()
        return .added(repository)
    }

    func addRepository(_ repository: Repository) {
        guard !repositories.contains(where: { $0.path == repository.path }) else { return }
        repositories.append(repository)
        scheduleSaveIfLoaded()
    }

    func updateRepository(_ repository: Repository) {
        guard let index = repositories.firstIndex(where: { $0.id == repository.id }) else { return }
        guard repositories[index] != repository else { return }
        repositories[index] = repository
        scheduleSaveIfLoaded()
    }

    func removeRepository(id: Repository.ID) {
        let before = repositories.count
        repositories.removeAll { $0.id == id }
        guard repositories.count != before else { return }
        scheduleSaveIfLoaded()
    }

    // MARK: - Scanning

    /// Whether a scan can run at all. Both conditions are things the user fixes
    /// in Settings, so the UI can point at them.
    var canScan: Bool {
        scanner != nil
            && !settings.gitAuthorEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && repositories.contains(where: \.enabled)
    }

    /// Read every enabled repository and collect commits not yet imported.
    func scanRepositories() async {
        guard !isScanning else { return }
        guard let scanner else {
            scanError = .executableUnavailable("Git was not found on this Mac.")
            return
        }

        let email = settings.gitAuthorEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            scanError = .commandFailed(status: 0, message: "Set your Git author email in Settings before scanning.")
            return
        }

        isScanning = true
        scanError = nil
        defer { isScanning = false }

        AppLog.scan.info("Scanning \(self.repositories.filter(\.enabled).count) repositories")

        // A commit already in the feed keeps its SHA as its id, so the feed
        // itself is the record of what has been imported.
        let known = Set(shippedItems.compactMap(\.commitSHA))

        let report = await scanner.scan(
            repositories: repositories,
            authorEmail: email,
            knownCommitSHAs: known
        )

        lastScanReport = report

        // Score what was found and put it straight into the feed. The SHA is
        // the item id, so this stays idempotent however often it runs.
        let imported = report.newCommits.map(scoringEngine.shippedItem(for:))
        lastImportCount = imported.count
        add(contentsOf: imported)

        AppLog.scan.info(
            """
            Scan finished in \(report.duration, format: .fixed(precision: 2))s: \
            \(report.scannedRepositoryCount) repositories read, \
            \(report.newCommits.count) commits imported, \
            \(report.failedRepositories.count) failed
            """
        )
        for result in report.results {
            if let error = result.error {
                AppLog.scan.error("\(result.repositoryName, privacy: .public): \(error.shortDescription, privacy: .public)")
            } else {
                AppLog.scan.info("\(result.repositoryName, privacy: .public): \(result.matchingCommits) mine, \(result.newCommits.count) new")
            }
        }
    }

    func dismissScanError() {
        scanError = nil
    }

    /// Fill in the Git author email from the machine's global git config.
    func detectGitAuthorEmail() async -> Bool {
        guard let scanner, let email = await scanner.runner.detectGlobalAuthorEmail() else {
            return false
        }
        settings.gitAuthorEmail = email
        return true
    }

    // MARK: - Background scanning

    private var backgroundScanTask: Task<Void, Never>?

    /// Whether the periodic background loop is currently running. Exposed for
    /// the settings UI and for tests — the loop itself has no other visible
    /// state between scans.
    var isBackgroundScanning: Bool { backgroundScanTask != nil }

    /// When the most recent scan — background or manual — finished.
    var lastScanAt: Date? { lastScanReport?.finishedAt }

    /// (Re)start the periodic scan loop from the current settings. Cancels
    /// any loop already running, so this is safe to call whenever the
    /// interval or the on/off switch changes, not just at launch.
    func restartBackgroundScanning() {
        backgroundScanTask?.cancel()
        backgroundScanTask = nil
        guard settings.isBackgroundScanningEnabled else { return }

        let minutes = max(settings.scanIntervalMinutes, VelocitySettings.minimumScanIntervalMinutes)
        let interval = Duration.seconds(minutes * 60)
        backgroundScanTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self else { return }
                if self.canScan { await self.scanRepositories() }
            }
        }
    }

    /// Scan once if the menu-bar panel is configured to do so on open.
    /// A no-op while a scan is already running, so opening the panel twice
    /// in a row cannot queue a second scan behind the first.
    func scanOnMenuOpenIfEnabled() {
        guard settings.scanOnMenuOpen, !isScanning else { return }
        Task { await scanRepositories() }
    }

    // MARK: - Derived reads

    /// Items matching the current dashboard filter, newest first.
    var filteredItems: [ShippedItem] {
        items(matching: scopeFilter)
    }

    func items(matching filter: ScopeFilter) -> [ShippedItem] {
        shippedItems.filter { filter.matches($0.scope) }
    }

    /// Items shipped today, newest first. Drives the menu-bar summary.
    func itemsShippedToday(now: Date = .now, calendar: Calendar = .current) -> [ShippedItem] {
        shippedItems.filter { calendar.isDate($0.timestamp, inSameDayAs: now) }
    }

    func pointsShippedToday(now: Date = .now, calendar: Calendar = .current) -> Int {
        itemsShippedToday(now: now, calendar: calendar).reduce(0) { $0 + $1.points }
    }

    // MARK: - Monthly analytics

    /// How many days of the current month have happened so far. The series
    /// stops here rather than padding in future days with zeroed points.
    func daysElapsedThisMonth(now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.component(.day, from: now)
    }

    /// Cumulative daily series for the current month, filtered to
    /// `scopeFilter`, through today. Drives the dashboard chart.
    func monthlyVelocities(now: Date = .now, calendar: Calendar = .current) -> [DailyVelocity] {
        VelocityAggregator.dailyVelocities(
            items: filteredItems,
            month: now,
            lastDay: daysElapsedThisMonth(now: now, calendar: calendar),
            calendar: calendar
        )
    }

    /// The target path for the current month at the configured daily rate.
    func monthlyGoal(now: Date = .now, calendar: Calendar = .current) -> VelocityGoal {
        VelocityGoal(
            targetDailyVelocity: settings.targetDailyVelocity,
            daysInMonth: calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        )
    }

    /// Average points per day shipped so far this month, for the current
    /// scope filter.
    func averageDailyVelocity(now: Date = .now, calendar: Calendar = .current) -> Double {
        let series = monthlyVelocities(now: now, calendar: calendar)
        guard let last = series.last, last.day > 0 else { return 0 }
        return Double(last.cumulativePoints) / Double(last.day)
    }

    /// Items shipped on `day` of the current month, for the current scope
    /// filter. Backs the month-inspection slider's "delivered on day N" list.
    func items(shippedOnDay day: Int, now: Date = .now, calendar: Calendar = .current) -> [ShippedItem] {
        filteredItems.filter {
            calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month)
                && calendar.component(.day, from: $0.timestamp) == day
        }
    }
}
