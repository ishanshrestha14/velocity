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

    // MARK: - Dependencies

    private let persistence: PersistenceService?
    private var saveTask: Task<Void, Never>?

    /// How long to wait after a change before writing. Collapses a burst of
    /// edits — or a scan importing many commits — into one write.
    private let saveDebounce = Duration.milliseconds(400)

    // MARK: - Init

    init(
        persistence: PersistenceService? = nil,
        data: VelocityData = .empty,
        startupError: PersistenceError? = nil
    ) {
        self.persistence = persistence
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

    func addRepository(_ repository: Repository) {
        guard !repositories.contains(where: { $0.path == repository.path }) else { return }
        repositories.append(repository)
        scheduleSaveIfLoaded()
    }

    func removeRepository(id: Repository.ID) {
        let before = repositories.count
        repositories.removeAll { $0.id == id }
        guard repositories.count != before else { return }
        scheduleSaveIfLoaded()
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
