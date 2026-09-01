import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            RepositorySettingsView()
                .tabItem { Label("Repositories", systemImage: "folder") }
        }
        .frame(minWidth: 560, minHeight: 260)
    }
}
