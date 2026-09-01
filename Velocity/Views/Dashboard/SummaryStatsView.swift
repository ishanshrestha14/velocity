import SwiftUI

/// Today's totals for the selected scope.
///
/// Month-level statistics (average velocity, monthly target, cumulative
/// progress) are derived from aggregation logic added alongside the chart.
struct SummaryStatsView: View {
    let points: Int
    let itemCount: Int
    let targetDailyVelocity: Double

    var body: some View {
        HStack(spacing: 12) {
            StatTile(
                label: "Shipped Today",
                value: "\(points)",
                unit: points == 1 ? "point" : "points",
                tint: .green
            )
            StatTile(
                label: "Items Today",
                value: "\(itemCount)",
                unit: itemCount == 1 ? "item" : "items",
                tint: .primary
            )
            StatTile(
                label: "Daily Target",
                value: targetDailyVelocity.formatted(.number.precision(.fractionLength(0...2))),
                unit: "per day",
                tint: .yellow
            )
        }
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let unit: String
    let tint: Color

    var body: some View {
        DashboardCard(title: label) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit)")
    }
}
