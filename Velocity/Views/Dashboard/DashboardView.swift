import SwiftUI

/// The main analytics window: this month's cumulative chart against the goal
/// path, headline stats, a day-by-day inspector, and the full shipped feed.
struct DashboardView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        @Bindable var store = appEnvironment.store
        let items = store.filteredItems
        let series = store.monthlyVelocities()
        let maxDay = max(store.daysElapsedThisMonth(), 1)

        // A window shrunk below the content's natural height must still
        // reach every section, so the whole dashboard scrolls rather than
        // clipping silently when it no longer fits.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(store: store)

                if !store.hasLoaded {
                    LoadingView()
                } else {
                    if let error = store.persistenceError {
                        PersistenceBanner(error: error) {
                            store.dismissPersistenceError()
                        } onRevealBackups: {
                            store.revealDataDirectory()
                        }
                    }

                    SummaryStatsView(
                        averageVelocity: store.averageDailyVelocity(),
                        delivered: store.filteredItems.reduce(0) { $0 + $1.points },
                        targetGoal: store.monthlyGoal().monthlyTarget
                    )

                    DashboardCard(title: "Cumulative Velocity") {
                        VelocityChartView(
                            series: series,
                            goal: store.monthlyGoal(),
                            scopeFilter: store.scopeFilter,
                            inspectedDay: min(store.inspectedDay, maxDay)
                        )
                    }

                    DashboardCard {
                        MonthInspectionView(
                            day: Binding(
                                get: { min(store.inspectedDay, maxDay) },
                                set: { store.inspectedDay = $0 }
                            ),
                            maxDay: maxDay,
                            items: store.items(shippedOnDay: min(store.inspectedDay, maxDay)),
                            dayLabel: dayLabel(for: min(store.inspectedDay, maxDay), in: series)
                        )
                    }

                    DashboardCard(title: "Shipped") {
                        ShippedFeedView(
                            items: items,
                            onDelete: { store.delete(id: $0) },
                            onChangeWeight: { store.setWeight($1, forItemWith: $0) },
                            onChangeScope: { store.setScope($1, forItemWith: $0) }
                        )
                        .frame(minHeight: 160)
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 720, alignment: .leading)
        }
        .frame(minWidth: 720, minHeight: 360)
        .animation(.default, value: store.hasLoaded)
    }

    private func dayLabel(for day: Int, in series: [DailyVelocity]) -> String {
        guard let point = series.first(where: { $0.day == day }) else { return "Day \(day)" }
        return point.date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func header(store: VelocityStore) -> some View {
        @Bindable var store = store
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Velocity")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(Date.now, format: .dateTime.month(.wide).year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProjectScopePicker(selection: $store.scopeFilter)
        }
    }
}

/// Shown briefly while the on-disk snapshot is still being read, so the
/// dashboard never flashes an empty state that looks like "nothing shipped."
private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading your shipping history…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#Preview {
    DashboardView()
        .environment(AppEnvironment(store: VelocityStore()))
}
