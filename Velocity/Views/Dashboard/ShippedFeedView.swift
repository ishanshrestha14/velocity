import SwiftUI

/// Chronological feed of shipped work, newest first.
struct ShippedFeedView: View {
    let items: [ShippedItem]
    var onDelete: ((ShippedItem.ID) -> Void)?
    var onChangeWeight: ((ShippedItem.ID, ImpactWeight) -> Void)?
    var onChangeScope: ((ShippedItem.ID, ProjectScope) -> Void)?

    var body: some View {
        if items.isEmpty {
            EmptyFeedView()
        } else {
            List(items) { item in
                ShippedItemRow(
                    item: item,
                    onDelete: onDelete,
                    onChangeWeight: onChangeWeight,
                    onChangeScope: onChangeScope
                )
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct ShippedItemRow: View {
    let item: ShippedItem
    let onDelete: ((ShippedItem.ID) -> Void)?
    var onChangeWeight: ((ShippedItem.ID, ImpactWeight) -> Void)?
    var onChangeScope: ((ShippedItem.ID, ProjectScope) -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            ImpactBadge(weight: item.weight)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)
                Text(item.scope.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(item.timestamp, format: .dateTime.hour().minute())
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if item.source == .git {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Imported from Git")
            }

            // Revealed on hover so the row stays quiet until you reach for it,
            // but delete is never hidden behind a right-click alone.
            if let onDelete {
                Button {
                    onDelete(item.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .opacity(isHovering ? 1 : 0)
                .help("Delete this item")
                .accessibilityLabel("Delete \(item.title)")
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .contextMenu {
            if let onChangeWeight {
                Menu("Impact") {
                    ForEach(ImpactWeight.allCases) { weight in
                        Button {
                            onChangeWeight(item.id, weight)
                        } label: {
                            if weight == item.weight {
                                Label("\(weight.points) · \(weight.displayName)", systemImage: "checkmark")
                            } else {
                                Text("\(weight.points) · \(weight.displayName)")
                            }
                        }
                    }
                }
            }
            if let onChangeScope {
                Menu("Scope") {
                    ForEach(ProjectScope.allCases) { scope in
                        Button {
                            onChangeScope(item.id, scope)
                        } label: {
                            if scope == item.scope {
                                Label(scope.displayName, systemImage: "checkmark")
                            } else {
                                Text(scope.displayName)
                            }
                        }
                    }
                }
            }
            if let onDelete {
                Divider()
                Button("Delete", role: .destructive) { onDelete(item.id) }
            }
        }
    }
}

private struct EmptyFeedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Nothing shipped yet", systemImage: "shippingbox")
        } description: {
            Text("Add a repository in Settings to import Git commits, or use Quick Log in the menu bar.")
        }
    }
}
