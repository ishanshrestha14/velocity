import Foundation
import Observation

/// Composition root. Owns the store and the services it depends on, so views
/// never construct their own dependencies.
@MainActor
@Observable
final class AppEnvironment {
    let store: VelocityStore

    init(store: VelocityStore) {
        self.store = store
    }

    /// The real environment: state backed by JSON in Application Support.
    ///
    /// Loading starts immediately rather than waiting for a view to appear —
    /// the menu bar label shows today's total before any window is opened.
    static func live() -> AppEnvironment {
        // A machine without the command line tools still gets a working app;
        // scanning is simply unavailable and says so.
        let scanner = try? GitScanner.locate()

        let store: VelocityStore
        do {
            store = VelocityStore(persistence: try PersistenceService(), scanner: scanner)
        } catch {
            // Without a data folder the app still runs, but the user is told
            // that nothing will be saved rather than losing work silently.
            store = VelocityStore(
                scanner: scanner,
                startupError: .directoryUnavailable(error.localizedDescription)
            )
        }
        let environment = AppEnvironment(store: store)
        Task { await store.load() }
        return environment
    }
}
