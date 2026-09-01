import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        @Bindable var store = appEnvironment.store
        Form {
            TextField(
                "Target daily velocity",
                value: $store.settings.targetDailyVelocity,
                format: .number.precision(.fractionLength(0...2))
            )
            .help("Points per day you are aiming to ship.")

            TextField("Git author email", text: $store.settings.gitAuthorEmail)
                .help("Only commits by this author are imported.")
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }
}
