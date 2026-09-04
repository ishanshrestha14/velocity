import SwiftUI

/// This month's headline numbers for the selected scope: how fast, how much,
/// and against what target.
struct SummaryStatsView: View {
    let averageVelocity: Double
    let delivered: Int
    let targetGoal: Double

    var body: some View {
        HStack(spacing: 12) {
            StatTile(
                label: "Avg Velocity",
                value: averageVelocity.formatted(.number.precision(.fractionLength(0...1))),
                unit: "/day",
                tint: .primary
            )
            StatTile(
                label: "Delivered",
                value: "\(delivered)",
                unit: delivered == 1 ? "point" : "points",
                tint: .green
            )
            StatTile(
                label: "Target Goal",
                value: targetGoal.formatted(.number.precision(.fractionLength(0...1))),
                unit: "points",
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
