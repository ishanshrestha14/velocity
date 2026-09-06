import Combine
import Observation
import Sparkle

/// Wraps Sparkle so nothing outside this file imports it.
///
/// Sparkle handles *application* updates only: checking `SUFeedURL`,
/// verifying a release's EdDSA signature, and installing a newer build. It
/// has nothing to do with Velocity's data — `VelocityData` stays local JSON
/// on this Mac either way (see README's Auto-Updates section).
@MainActor
@Observable
final class UpdateService {
    private let controller: SPUStandardUpdaterController
    private var cancellable: AnyCancellable?

    /// Whether "Check for Updates…" should be enabled right now — Sparkle
    /// disables it while a check or install is already in progress.
    private(set) var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // SPUUpdater's properties are KVO, not Observation-compliant, so a
        // Combine bridge is what actually notifies this @Observable type.
        cancellable = controller.updater.publisher(for: \.canCheckForUpdates)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
