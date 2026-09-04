import Foundation
import Testing
@testable import Velocity

struct VelocityAggregatorTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, month: Int = 9, year: Int = 2026, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func item(day: Int, weight: ImpactWeight, scope: ProjectScope = .personal) -> ShippedItem {
        ShippedItem(
            id: UUID().uuidString,
            title: "Item",
            timestamp: date(day),
            scope: scope,
            weight: weight,
            source: .manual
        )
    }

    @Test func emptyMonthProducesZeroedDays() {
        let series = VelocityAggregator.dailyVelocities(items: [], month: date(1), lastDay: 5, calendar: calendar)

        #expect(series.count == 5)
        #expect(series.map(\.day) == [1, 2, 3, 4, 5])
        #expect(series.allSatisfy { $0.points == 0 && $0.cumulativePoints == 0 && $0.itemCount == 0 })
    }

    @Test func pointsAccumulateAcrossDays() {
        let items = [
            item(day: 1, weight: .core),   // 3
            item(day: 3, weight: .minor),  // 1
            item(day: 3, weight: .epic),   // 5
        ]
        let series = VelocityAggregator.dailyVelocities(items: items, month: date(1), lastDay: 4, calendar: calendar)

        #expect(series[0].points == 3)
        #expect(series[0].cumulativePoints == 3)
        #expect(series[1].points == 0)
        #expect(series[1].cumulativePoints == 3)
        #expect(series[2].points == 6)
        #expect(series[2].cumulativePoints == 9)
        #expect(series[2].itemCount == 2)
        #expect(series[3].cumulativePoints == 9)
    }

    @Test func itemsOutsideTheMonthAreExcluded() {
        let items = [
            item(day: 1, weight: .core, scope: .personal),
            ShippedItem(
                id: "aug",
                title: "August item",
                timestamp: date(28, month: 8),
                scope: .personal,
                weight: .epic,
                source: .manual
            ),
        ]
        let series = VelocityAggregator.dailyVelocities(items: items, month: date(1), calendar: calendar)

        #expect(series.reduce(0) { $0 + $1.points } == 3)
    }

    @Test func lastDayClampsToDaysInMonth() {
        let series = VelocityAggregator.dailyVelocities(items: [], month: date(1), lastDay: 999, calendar: calendar)
        #expect(series.count == 30)
    }

    @Test func nonPositiveLastDayProducesNoDays() {
        let series = VelocityAggregator.dailyVelocities(items: [], month: date(1), lastDay: 0, calendar: calendar)
        #expect(series.isEmpty)
    }

    @Test func defaultLastDayCoversTheWholeMonth() {
        let series = VelocityAggregator.dailyVelocities(items: [], month: date(1), calendar: calendar)
        #expect(series.count == 30)
        #expect(series.last?.day == 30)
    }
}
