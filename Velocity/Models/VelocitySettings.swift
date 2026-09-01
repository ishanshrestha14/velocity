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

    init(targetDailyVelocity: Double = 2.5, gitAuthorEmail: String = "") {
        self.targetDailyVelocity = targetDailyVelocity
        self.gitAuthorEmail = gitAuthorEmail
    }

    static let `default` = VelocitySettings()
}
