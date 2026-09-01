import Foundation
import Observation

/// Composition root. Owns the store today; Git, scoring, persistence, and export
/// services are wired in here as later phases add them, so views never construct
/// their own dependencies.
@MainActor
@Observable
final class AppEnvironment {
    let store: VelocityStore

    init(store: VelocityStore = VelocityStore()) {
        self.store = store
    }
}
