import SwiftUI

@main
struct VelocityApp: App {
    var body: some Scene {
        Window("Velocity", id: WindowID.dashboard) {
            DashboardView()
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
