import Foundation

/// The target path for a month, derived from `targetDailyVelocity`.
///
/// Calculations keep full precision; only presentation rounds.
struct VelocityGoal: Hashable, Sendable {
    let targetDailyVelocity: Double
    let daysInMonth: Int

    /// Total points targeted for the whole month.
    var monthlyTarget: Double {
        targetDailyVelocity * Double(daysInMonth)
    }

    /// The cumulative target at the end of `day` (1-based).
    func cumulativeTarget(throughDay day: Int) -> Double {
        targetDailyVelocity * Double(max(0, min(day, daysInMonth)))
    }
}
