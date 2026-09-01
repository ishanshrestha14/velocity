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
        didSet { scheduleSaveIfLoaded() }
    }

    // MARK: - View state (never persisted)

    /// Dashboard scope filter. Analytics-only: it never alters stored data.
    var scopeFilter: ScopeFilter = .all

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

    /// Commits found by the last scan that are not yet in the feed.
    ///
    /// They stay here rather than becoming shipped items because turning a
    /// commit into a score is the scoring engine's job, which does not exist
    /// yet. Nothing invents a weight in the meantime.
    private(set) var pendingCommits: [DiscoveredCommit] = []

    // MARK: - Dependencies

    private let persistence: PersistenceService?
    private let scanner: GitScanner?
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
        guard let persistence else {
            hasLoaded = true
            return
        }
        let result = await persistence.load()
        applyLoaded(result.data)
        persistenceError = result.error
        hasLoaded = true
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

    func delete(id: ShippedItem.ID) {
        let before = shippedItems.count
        shippedItems.removeAll { $0.id == id }
        guard shippedItems.count != before else { return }
        scheduleSaveIfLoaded()
    }

    // MARK: - Repositories

    /// Add a repository after checking it is one.
    ///
    /// Throws rather than silently ignoring a bad path, so the settings screen
    /// can say what is actually wrong with the folder the user picked.
    func addRepository(path: String, scope: ProjectScope) async throws {
        let cleanPath = (path as NSString).standardizingPath
        guard !repositories.contains(where: { $0.path == cleanPath }) else { return }

        if let scanner {
            try await GitRepositoryValidator(runner: scanner.runner).validate(path: cleanPath)
        }

        repositories.append(
            Repository(
                name: GitRepositoryValidator.suggestedName(for: cleanPath),
                path: cleanPath,
                scope: scope
            )
        )
        scheduleSaveIfLoaded()
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
        pendingCommits.removeAll { commit in
            !repositories.contains { $0.path == commit.commit.repositoryPath }
        }
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
        pendingCommits = report.newCommits

        AppLog.scan.info(
            """
            Scan finished in \(report.duration, format: .fixed(precision: 2))s: \
            \(report.scannedRepositoryCount) repositories read, \
            \(report.newCommits.count) new commits, \
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
}
