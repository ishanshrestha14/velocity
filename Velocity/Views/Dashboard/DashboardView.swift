import SwiftUI

/// The main analytics window. Phase 1 establishes the layout, the scope filter,
/// and the feed; the cumulative Swift Charts view and month inspection land with
/// the aggregation logic that feeds them.
struct DashboardView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        @Bindable var store = appEnvironment.store
        let items = store.filteredItems
        let todayItems = store.itemsShippedToday().filter { store.scopeFilter.matches($0.scope) }

        VStack(alignment: .leading, spacing: 16) {
            header(store: store)

            if let error = store.persistenceError {
                PersistenceBanner(error: error) {
                    store.dismissPersistenceError()
                } onRevealBackups: {
                    store.revealDataDirectory()
                }
            }

            SummaryStatsView(
                points: todayItems.reduce(0) { $0 + $1.points },
                itemCount: todayItems.count,
                targetDailyVelocity: store.settings.targetDailyVelocity
            )

            DashboardCard(title: "Cumulative Velocity") {
                ChartPlaceholder()
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
        .padding(20)
        .frame(minWidth: 720, minHeight: 560)
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

/// Stands in for the Swift Charts view until real daily aggregation exists.
/// Deliberately not a fake chart — it renders no invented data.
private struct ChartPlaceholder: View {
    var body: some View {
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

#Preview {
    DashboardView()
        .environment(AppEnvironment(store: VelocityStore()))
}
