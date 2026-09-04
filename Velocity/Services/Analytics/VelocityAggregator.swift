import Foundation

/// Turns shipped items into the per-day series the chart and summary
/// statistics consume.
///
/// Pure and stateless — every input is a parameter, so it is tested without a
/// store, a clock, or a locale. Views and the store call this; neither one
/// re-implements the aggregation itself.
enum VelocityAggregator {
    /// One entry per day from the 1st of `month` through `lastDay`, inclusive.
    ///
    /// `lastDay` lets a caller stop the series at today instead of padding a
    /// month with zeroed-out future days that have not happened yet.
    /// Defaults to the whole month.
    static func dailyVelocities(
        items: [ShippedItem],
        month: Date,
        lastDay: Int? = nil,
        calendar: Calendar = .current
    ) -> [DailyVelocity] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        let upperDay = min(lastDay ?? daysInMonth, daysInMonth)
        guard upperDay >= 1 else { return [] }

        var pointsByDay: [Int: (points: Int, count: Int)] = [:]
        for item in items where interval.contains(item.timestamp) {
            let day = calendar.component(.day, from: item.timestamp)
            var entry = pointsByDay[day] ?? (points: 0, count: 0)
            entry.points += item.points
            entry.count += 1
            pointsByDay[day] = entry
        }

        var cumulative = 0
        var result: [DailyVelocity] = []
        result.reserveCapacity(upperDay)
        for day in 1...upperDay {
            let entry = pointsByDay[day] ?? (points: 0, count: 0)
            cumulative += entry.points
            let date = calendar.date(byAdding: .day, value: day - 1, to: interval.start) ?? interval.start
            result.append(
                DailyVelocity(
                    date: date,
                    day: day,
                    points: entry.points,
                    itemCount: entry.count,
                    cumulativePoints: cumulative
                )
            )
        }
        return result
    }
}
