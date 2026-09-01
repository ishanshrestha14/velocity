import SwiftUI

@main
struct VelocityApp: App {
    /// Owned here so the menu bar, dashboard, and settings all observe one store.
    @State private var environment = AppEnvironment()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(environment)
        } label: {
            MenuBarLabel(points: environment.store.pointsShippedToday())
        }
        // The window style gives full SwiftUI control over the panel, which an
        // NSMenu-backed menu cannot provide.
        .menuBarExtraStyle(.window)

        Window("Velocity Dashboard", id: WindowID.dashboard) {
            DashboardView()
                .environment(environment)
        }
        .defaultSize(width: 940, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .windowArrangement) {
                OpenDashboardCommand()
            }
        }

        Settings {
            SettingsView()
                .environment(environment)
        }
    }
}

/// Menu command + keyboard shortcut for the dashboard. Lives in a `View` so it
/// can reach the `openWindow` environment action.
private struct OpenDashboardCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Dashboard") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: WindowID.dashboard)
        }
        .keyboardShortcut("d", modifiers: .command)
    }
}

/// Stable identifiers for `openWindow`.
enum WindowID {
    static let dashboard = "dashboard"
}
