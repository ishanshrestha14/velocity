import Charts
import SwiftUI

/// Cumulative shipped points for the month against the goal path.
///
/// A vertical rule marks the day under inspection, with a callout showing
/// exactly what was true on that day — this is the "month inspection" surface
/// the slider below the chart drives.
struct VelocityChartView: View {
    let series: [DailyVelocity]
    let goal: VelocityGoal
    let scopeFilter: ScopeFilter
    let inspectedDay: Int

    private var scopeTint: Color {
        switch scopeFilter {
        case .all: .blue
        case .work: .indigo
        case .personal: .green
        }
    }

    /// The goal path as two endpoints — the month's start at zero, and the
    /// cumulative target through the last day the series covers. A straight
    /// line between them is all `LineMark` needs.
    private var goalPath: [(date: Date, points: Double)] {
        guard let first = series.first, let last = series.last else { return [] }
        return [
            (first.date, 0),
            (last.date, goal.cumulativeTarget(throughDay: last.day)),
        ]
    }

    private var inspectedPoint: DailyVelocity? {
        series.first { $0.day == inspectedDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            legend
            if series.isEmpty {
                emptyState
            } else {
                chart
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            LegendEntry(color: scopeTint, style: .solid, label: scopeFilter.displayName)
            LegendEntry(color: .yellow, style: .dashed, label: "Goal Path")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var chart: some View {
        Chart {
            ForEach(series) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Points", point.cumulativePoints)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [scopeTint.opacity(0.35), scopeTint.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Points", point.cumulativePoints)
                )
                .foregroundStyle(scopeTint)
                .interpolationMethod(.monotone)
            }

            ForEach(Array(goalPath.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Target", point.points),
                    series: .value("Series", "Goal")
                )
                .foregroundStyle(.yellow)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }

            if let last = series.last {
                PointMark(
                    x: .value("Date", last.date),
                    y: .value("Points", last.cumulativePoints)
                )
                .foregroundStyle(scopeTint)
                .symbolSize(50)
            }

            if let goalEnd = goalPath.last {
                PointMark(
                    x: .value("Date", goalEnd.date),
                    y: .value("Target", goalEnd.points)
                )
                .foregroundStyle(.yellow)
                .symbolSize(50)
            }

            if let inspectedPoint {
                RuleMark(x: .value("Date", inspectedPoint.date))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .annotation(position: .top, alignment: .center, spacing: 4) {
                        Text("Day \(inspectedPoint.day): \(inspectedPoint.cumulativePoints) points")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, series.count / 6))) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(minHeight: 200)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("The cumulative chart appears once shipped work is recorded.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }
}

private struct LegendEntry: View {
    enum Style { case solid, dashed }

    let color: Color
    let style: Style
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            switch style {
            case .solid:
                Circle().fill(color).frame(width: 8, height: 8)
            case .dashed:
                Rectangle()
                    .fill(color)
                    .frame(width: 14, height: 2)
            }
            Text(label)
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let month = Date.now
    let series = VelocityAggregator.dailyVelocities(
        items: [
            .manual(title: "feat: dark mode", scope: .personal, weight: .core),
            .manual(title: "fix: viewport", scope: .personal, weight: .minor),
        ],
        month: month,
        lastDay: calendar.component(.day, from: month),
        calendar: calendar
    )
    return VelocityChartView(
        series: series,
        goal: VelocityGoal(targetDailyVelocity: 2.5, daysInMonth: 30),
        scopeFilter: .personal,
        inspectedDay: calendar.component(.day, from: month)
    )
    .padding()
}
