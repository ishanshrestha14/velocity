import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var detectFailed = false
    @State private var exportError: String?

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
                Toggle("Scan automatically", isOn: $store.settings.isBackgroundScanningEnabled)
                    .help("Scan every enabled repository on a timer, without being asked.")

                Stepper(
                    "Every \(store.settings.scanIntervalMinutes) minutes",
                    value: $store.settings.scanIntervalMinutes,
                    in: VelocitySettings.minimumScanIntervalMinutes...180,
                    step: 5
                )
                .disabled(!store.settings.isBackgroundScanningEnabled)

                Toggle("Scan when the menu bar opens", isOn: $store.settings.scanOnMenuOpen)
                    .help("Also scan the moment the menu-bar panel is opened, in addition to the timer.")
            } header: {
                Text("Automation")
            } footer: {
                if let lastScanAt = store.lastScanAt {
                    Text("Last scanned \(lastScanAt.formatted(.relative(presentation: .named))).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Velocity has not scanned yet.")
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

                LabeledContent("Export a copy") {
                    Button("Export…") {
                        exportToChosenFile(store: store)
                    }
                    .help("Save everything Velocity has recorded as a standalone JSON file.")
                }

                if let exportError {
                    Text(exportError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    /// Presents a save panel, then writes the export off the main actor once
    /// the user has chosen where. Declined panels leave `exportError` alone.
    private func exportToChosenFile(store: VelocityStore) {
        let panel = NSSavePanel()
        panel.title = "Export Velocity Data"
        panel.nameFieldStringValue = "velocity-export.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    try await store.export(to: url)
                    exportError = nil
                } catch {
                    exportError = error.localizedDescription
                }
            }
        }
    }
}
