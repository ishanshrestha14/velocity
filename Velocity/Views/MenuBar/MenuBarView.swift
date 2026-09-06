import SwiftUI

/// The menu-bar panel. Kept deliberately light: a today summary and the few
/// actions worth reaching without opening a window.
struct MenuBarView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.openWindow) private var openWindow

    @State private var isQuickLogging = false

    private var store: VelocityStore { appEnvironment.store }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            todaySection
            Divider()
            if isQuickLogging {
                QuickLogView { isQuickLogging = false }
                Divider()
            }
            actions
            if let status = scanStatus {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    ScanStatusIndicator(
                        isScanning: store.isScanning,
                        hasError: store.scanError != nil
                    )
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 280)
        .onAppear { store.scanOnMenuOpenIfEnabled() }
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

            if !store.hasLoaded {
                Text("Loading…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else if items.isEmpty {
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
            MenuBarButton(title: "Quick Log", systemImage: "plus.circle") {
                isQuickLogging.toggle()
            }
            .disabled(isQuickLogging)

            MenuBarButton(title: "Open Dashboard", systemImage: "chart.line.uptrend.xyaxis") {
                openDashboard()
            }

            MenuBarButton(
                title: store.isScanning ? "Scanning…" : "Scan Repositories",
                systemImage: "arrow.triangle.2.circlepath"
            ) {
                Task { await store.scanRepositories() }
            }
            .disabled(store.isScanning || !store.canScan)

            SettingsLink {
                MenuBarButtonLabel(title: "Settings…", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings…")

            MenuBarButton(title: "Check for Updates…", systemImage: "arrow.down.circle") {
                appEnvironment.updateService.checkForUpdates()
            }
            .disabled(!appEnvironment.updateService.canCheckForUpdates)

            Divider()
                .padding(.vertical, 4)

            MenuBarButton(title: "Quit Velocity", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    /// One line about the last scan, or about what is stopping one.
    private var scanStatus: String? {
        if store.isScanning {
            return "Scanning…"
        }
        if let error = store.scanError {
            return error.errorDescription
        }
        guard let report = store.lastScanReport else {
            return store.canScan ? nil : "Add a repository and set your Git author email in Settings."
        }
        let imported = report.newCommits.count
        var line = "\(imported) commit\(imported == 1 ? "" : "s") imported"
        let failed = report.failedRepositories.count
        if failed > 0 {
            line += " · \(failed) failed"
        }
        if let lastScanAt = store.lastScanAt {
            line += " · \(lastScanAt.formatted(.relative(presentation: .named)))"
        }
        return line
    }

    private func openDashboard() {
        // An accessory app has no dock icon, so it must ask to come forward
        // before its window can take focus.
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: WindowID.dashboard)
    }
}

/// A small dot summarizing scan state at a glance: spinning while a scan
/// runs, red on the last scan's error, green once it finished cleanly.
private struct ScanStatusIndicator: View {
    let isScanning: Bool
    let hasError: Bool

    var body: some View {
        Group {
            if isScanning {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(hasError ? Color.red : Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 10, height: 10)
        .padding(.top, 3)
        .accessibilityHidden(true)
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
        // The hover-highlight background and hidden native label make this
        // read as an unnamed AXButton to System Events without an explicit
        // label — the automatic inference from `Label`'s text does not carry
        // through a fully custom-styled button (see PROGRESS.md D3).
        .accessibilityLabel(title)
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
        .environment(AppEnvironment(store: VelocityStore()))
}
