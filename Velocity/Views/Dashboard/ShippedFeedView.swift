import SwiftUI

/// Chronological feed of shipped work, newest first.
struct ShippedFeedView: View {
    let items: [ShippedItem]
    var onDelete: ((ShippedItem.ID) -> Void)?

    var body: some View {
        if items.isEmpty {
            EmptyFeedView()
        } else {
            List(items) { item in
                ShippedItemRow(item: item, onDelete: onDelete)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }
}

private struct ShippedItemRow: View {
    let item: ShippedItem
    let onDelete: ((ShippedItem.ID) -> Void)?

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
        }
        .padding(.vertical, 2)
        .contextMenu {
            if let onDelete {
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
            Text("Add a repository in Settings to import Git commits, or log a shipment manually.")
        }
    }
}
