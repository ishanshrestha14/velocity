import Foundation
import Observation

/// The single source of truth for application state.
///
/// Views read from this and call its methods; they never mutate state directly
/// and never contain aggregation, Git, or persistence logic. Services (Git,
/// persistence, scoring) are introduced in later phases and will hand their
/// results to this store rather than to views.
@MainActor
@Observable
final class VelocityStore {
    // MARK: - Persisted state

    private(set) var shippedItems: [ShippedItem] = []
    private(set) var repositories: [Repository] = []
    var settings: VelocitySettings = .default

    // MARK: - View state (never persisted)

    /// Dashboard scope filter. Analytics-only: it never alters stored data.
    var scopeFilter: ScopeFilter = .all

    // MARK: - Init

    init(data: VelocityData = .empty) {
        apply(data)
    }

    // MARK: - Snapshot

    /// The full state as a serializable document. Phase 2 persists this.
    var snapshot: VelocityData {
        VelocityData(items: shippedItems, repositories: repositories, settings: settings)
    }

    /// Replace all state with a loaded document.
    func apply(_ data: VelocityData) {
        shippedItems = data.items.sorted { $0.timestamp > $1.timestamp }
        repositories = data.repositories
        settings = data.settings
    }

    // MARK: - Shipped items

    /// Insert an item, keeping the feed newest-first.
    ///
    /// Items are keyed by `id` — the Git SHA for Git-derived shipments — so
    /// re-adding the same commit updates it in place instead of duplicating it.
    func add(_ item: ShippedItem) {
        if let existing = shippedItems.firstIndex(where: { $0.id == item.id }) {
            shippedItems[existing] = item
        } else {
            shippedItems.append(item)
        }
        shippedItems.sort { $0.timestamp > $1.timestamp }
    }

    /// Insert many items at once, deduplicating by id.
    func add(contentsOf items: [ShippedItem]) {
        for item in items {
            if let existing = shippedItems.firstIndex(where: { $0.id == item.id }) {
                shippedItems[existing] = item
            } else {
                shippedItems.append(item)
            }
        }
        shippedItems.sort { $0.timestamp > $1.timestamp }
    }

    func delete(id: ShippedItem.ID) {
        shippedItems.removeAll { $0.id == id }
    }

    // MARK: - Repositories

    func addRepository(_ repository: Repository) {
        guard !repositories.contains(where: { $0.path == repository.path }) else { return }
        repositories.append(repository)
    }

    func removeRepository(id: Repository.ID) {
        repositories.removeAll { $0.id == id }
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
