import SwiftUI

@main
struct VelocityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Owned here so the menu bar, dashboard, and settings all observe one store.
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(environment)
        } label: {
            MenuBarLabel(points: environment.store.pointsShippedToday())
                // The status item is always present, unlike the panel's
                // contents, so this is where the delegate reliably gets wired.
                .onAppear { appDelegate.environment = environment }
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

/// Flushes any debounced save before the process goes away.
///
/// SwiftUI has no scene hook for termination, so this is the one place an
/// AppKit delegate earns its keep.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor var environment: AppEnvironment?

    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        environment?.store.flushPendingSave()
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
