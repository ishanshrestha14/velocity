import Foundation

/// Points shipped on a single calendar day, plus the running total for the month.
///
/// This is the shape the cumulative chart consumes. It is produced by aggregation
/// logic, never computed inside a `View` body.
struct DailyVelocity: Identifiable, Hashable, Sendable {
    /// Start-of-day for the day being described.
    let date: Date
    /// Day of month, 1-based.
    let day: Int
    /// Points shipped on this day alone.
    let points: Int
    /// Number of items shipped on this day alone.
    let itemCount: Int
    /// Points shipped from the first of the month through this day, inclusive.
    let cumulativePoints: Int

    var id: Date { date }
}
