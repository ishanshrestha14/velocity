import SwiftUI

/// Lets the dashboard be scrubbed back through the month: a slider picks a
/// day, and the badges below show exactly what shipped on it.
struct MonthInspectionView: View {
    @Binding var day: Int
    let maxDay: Int
    let items: [ShippedItem]
    let dayLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Inspect Month Progress")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Day \(day)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(day) },
                    set: { day = Int($0.rounded()) }
                ),
                in: 1...Double(max(maxDay, 1)),
                step: 1
            )
            .disabled(maxDay <= 1)
            .accessibilityLabel("Inspect month progress")
            .accessibilityValue("Day \(day)")

            if items.isEmpty {
                Text("Nothing delivered on \(dayLabel).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Delivered on \(dayLabel):")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(items) { item in
                        DeliveredBadge(item: item)
                    }
                }
            }
        }
    }
}

private struct DeliveredBadge: View {
    let item: ShippedItem

    var body: some View {
        Label(item.title, systemImage: "leaf.fill")
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(tint.opacity(0.16))
            )
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch item.scope {
        case .work: .indigo
        case .personal: .green
        }
    }
}

/// A simple wrapping row layout — badges flow to the next line instead of
/// being clipped or forced into a horizontal scroll view.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrangeRows(subviews: subviews, maxWidth: width)
        let height = rows.reduce(0) { $0 + $1.height + spacing } - (rows.isEmpty ? 0 : spacing)
        return CGSize(width: width.isFinite ? width : rows.map(\.width).max() ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeRows(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for element in row.elements {
                element.subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct RowElement {
        let subview: LayoutSubview
        let size: CGSize
    }

    private struct Row {
        let elements: [RowElement]
        let width: CGFloat
        let height: CGFloat
    }

    private func arrangeRows(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current: [RowElement] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if !current.isEmpty, currentWidth + spacing + size.width > maxWidth {
                rows.append(Row(elements: current, width: currentWidth, height: currentHeight))
                current = []
                currentWidth = 0
                currentHeight = 0
            }
            if !current.isEmpty { currentWidth += spacing }
            current.append(RowElement(subview: subview, size: size))
            currentWidth += size.width
            currentHeight = max(currentHeight, size.height)
        }
        if !current.isEmpty {
            rows.append(Row(elements: current, width: currentWidth, height: currentHeight))
        }
        return rows
    }
}

#Preview {
    MonthInspectionView(
        day: .constant(15),
        maxDay: 30,
        items: [
            .manual(title: "Dark mode", scope: .personal, weight: .core),
            .manual(title: "CSS injection", scope: .personal, weight: .minor),
            .manual(title: "Fix viewport", scope: .work, weight: .minor),
        ],
        dayLabel: "Sep 15"
    )
    .padding()
}
