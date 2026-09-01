import SwiftUI

/// The menu-bar panel. Kept deliberately light: a today summary and the few
/// actions worth reaching without opening a window.
struct MenuBarView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    private var store: VelocityStore { appEnvironment.store }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            todaySection
            Divider()
            actions
        }
        .frame(width: 280)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Velocity")
                .font(.headline)
            Spacer()
            Text("\(store.pointsShippedToday()) pts")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var todaySection: some View {
        let items = store.itemsShippedToday()
        return VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if items.isEmpty {
                Text("Nothing shipped yet today.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(items) { item in
                    MenuBarItemRow(item: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var actions: some View {
        VStack(spacing: 2) {
            MenuBarButton(title: "Quit Velocity", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

private struct MenuBarItemRow: View {
    let item: ShippedItem

    var body: some View {
        HStack(spacing: 8) {
            ImpactBadge(weight: item.weight)
            Text(item.title)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A row that reads as a menu item but is a real SwiftUI button.
private struct MenuBarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MenuBarButtonLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

private struct MenuBarButtonLabel: View {
    let title: String
    let systemImage: String

    @State private var isHovering = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(.rect)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovering ? Color.accentColor.opacity(0.18) : .clear)
            )
            .onHover { isHovering = $0 }
    }
}

#Preview {
    MenuBarView()
        .environment(AppEnvironment())
}
