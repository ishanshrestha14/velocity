import SwiftUI

@main
struct VelocityApp: App {
    /// Owned here so every scene observes one store.
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
        }
    }
}

/// Stable identifiers for `openWindow`.
enum WindowID {
    static let dashboard = "dashboard"
}
