import Foundation

/// User-configurable preferences. Kept small and flat so it round-trips through
/// JSON without migration pain.
struct VelocitySettings: Codable, Hashable, Sendable {
    /// Points per day the user is aiming for. Fractional on purpose — the goal
    /// path is computed at full precision and only rounded for display.
    var targetDailyVelocity: Double
    /// The Git author email whose commits count. Explicitly configured rather
    /// than inferred from the machine's identity.
    var gitAuthorEmail: String
    /// Whether Velocity scans on its own, rather than only when asked.
    var isBackgroundScanningEnabled: Bool
    /// Minutes between automatic scans. Only meaningful while background
    /// scanning is enabled.
    var scanIntervalMinutes: Int
    /// Scan once whenever the menu-bar panel is opened, in addition to the
    /// interval above.
    var scanOnMenuOpen: Bool

    static let defaultScanIntervalMinutes = 30
    static let minimumScanIntervalMinutes = 5

    init(
        targetDailyVelocity: Double = 2.5,
        gitAuthorEmail: String = "",
        isBackgroundScanningEnabled: Bool = true,
        scanIntervalMinutes: Int = VelocitySettings.defaultScanIntervalMinutes,
        scanOnMenuOpen: Bool = false
    ) {
        self.targetDailyVelocity = targetDailyVelocity
        self.gitAuthorEmail = gitAuthorEmail
        self.isBackgroundScanningEnabled = isBackgroundScanningEnabled
        self.scanIntervalMinutes = scanIntervalMinutes
        self.scanOnMenuOpen = scanOnMenuOpen
    }

    static let `default` = VelocitySettings()

    // MARK: - Codable

    // Hand-written rather than synthesized: the three automation fields were
    // added in Phase 6, and a settings file saved before then has none of
    // them. Missing keys fall back to their defaults instead of failing the
    // whole document — a decode failure quarantines the entire data file
    // (see `PersistenceService.load`), which would silently wipe an existing
    // user's items and repositories just for gaining an unrelated feature.
    private enum CodingKeys: String, CodingKey {
        case targetDailyVelocity, gitAuthorEmail, isBackgroundScanningEnabled, scanIntervalMinutes, scanOnMenuOpen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = VelocitySettings.default
        targetDailyVelocity = try container.decodeIfPresent(Double.self, forKey: .targetDailyVelocity)
            ?? fallback.targetDailyVelocity
        gitAuthorEmail = try container.decodeIfPresent(String.self, forKey: .gitAuthorEmail)
            ?? fallback.gitAuthorEmail
        isBackgroundScanningEnabled = try container.decodeIfPresent(Bool.self, forKey: .isBackgroundScanningEnabled)
            ?? fallback.isBackgroundScanningEnabled
        scanIntervalMinutes = try container.decodeIfPresent(Int.self, forKey: .scanIntervalMinutes)
            ?? fallback.scanIntervalMinutes
        scanOnMenuOpen = try container.decodeIfPresent(Bool.self, forKey: .scanOnMenuOpen)
            ?? fallback.scanOnMenuOpen
    }
}
