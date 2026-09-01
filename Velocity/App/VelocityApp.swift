import SwiftUI

@main
struct VelocityApp: App {
    /// Owned here so every scene observes one store.
    @State private var environment = AppEnvironment()

    var body: some Scene {
        Window("Velocity", id: WindowID.dashboard) {
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
