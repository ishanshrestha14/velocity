import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var detectFailed = false

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

                LabeledContent("Git author email") {
                    HStack(spacing: 8) {
                        TextField("Git author email", text: $store.settings.gitAuthorEmail)
                            .labelsHidden()
                            .help("Only commits by this author are imported.")
                        Button("Detect") {
                            Task {
                                detectFailed = await !store.detectGitAuthorEmail()
                            }
                        }
                        .help("Read user.email from this Mac's global git config.")
                    }
                }
                if detectFailed {
                    Text("No global user.email is set in git config.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
