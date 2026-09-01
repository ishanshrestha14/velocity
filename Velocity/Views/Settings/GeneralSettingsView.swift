import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    var body: some View {
        @Bindable var store = appEnvironment.store
        Form {
            Section {
                TextField(
                    "Target daily velocity",
                    value: $store.settings.targetDailyVelocity,
                    format: .number.precision(.fractionLength(0...2))
                )
                .help("Points per day you are aiming to ship.")

                TextField("Git author email", text: $store.settings.gitAuthorEmail)
                    .help("Only commits by this author are imported.")
            }

            Section {
                LabeledContent("Stored at") {
                    HStack(spacing: 8) {
                        Text(store.dataDirectoryURL?.path(percentEncoded: false) ?? "Not available")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                        Button("Show in Finder") {
                            store.revealDataDirectory()
                        }
                        .disabled(store.dataDirectoryURL == nil)
                    }
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Velocity keeps everything on this Mac as plain JSON. Nothing is sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }
}
