import AppKit
import SwiftUI

/// Manage the repositories Velocity reads.
///
/// Each row carries the scope that classifies its commits as work or personal,
/// which is what keeps that decision out of the scan itself.
struct RepositorySettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var addError: GitError?
    @State private var isAdding = false

    private var store: VelocityStore { appEnvironment.store }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.repositories.isEmpty {
                emptyState
            } else {
                repositoryList
            }

            if let addError {
                errorRow(addError)
            }

            HStack {
                Button {
                    chooseRepository()
                } label: {
                    Label("Add Repository…", systemImage: "plus")
                }
                .disabled(isAdding)

                Spacer()

                if let report = store.lastScanReport {
                    Text(scanSummary(report))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await store.scanRepositories() }
                } label: {
                    if store.isScanning {
                        Text("Scanning…")
                    } else {
                        Text("Scan Now")
                    }
                }
                .disabled(store.isScanning || !store.canScan)
                .help(store.canScan
                      ? "Read new commits from every enabled repository."
                      : "Add a repository and set your Git author email first.")
            }
        }
        .padding(20)
        .frame(width: 560, height: 380, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No repositories yet")
                .fontWeight(.semibold)
            Text("Add a local Git repository and Velocity will read your commits from it.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }

    private var repositoryList: some View {
        List {
            ForEach(store.repositories) { repository in
                RepositoryRow(
                    repository: repository,
                    result: store.lastScanReport?.results.first { $0.repositoryID == repository.id },
                    onChange: { store.updateRepository($0) },
                    onRemove: { store.removeRepository(id: repository.id) }
                )
            }
        }
        .listStyle(.inset)
        .frame(maxHeight: .infinity)
    }

    private func errorRow(_ error: GitError) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "Could not add that folder.")
                    .fontWeight(.semibold)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    private func scanSummary(_ report: ScanReport) -> String {
        let new = report.newCommits.count
        let failed = report.failedRepositories.count
        var parts = ["\(new) new commit\(new == 1 ? "" : "s")"]
        if failed > 0 {
            parts.append("\(failed) repository\(failed == 1 ? "" : " repositories") failed")
        }
        return parts.joined(separator: " · ")
    }

    private func chooseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        panel.message = "Choose the top level of a Git repository."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isAdding = true
        addError = nil
        Task {
            defer { isAdding = false }
            do {
                try await store.addRepository(path: url.path(percentEncoded: false), scope: .personal)
            } catch let error as GitError {
                addError = error
            } catch {
                addError = .commandFailed(status: -1, message: error.localizedDescription)
            }
        }
    }
}

private struct RepositoryRow: View {
    let repository: Repository
    let result: RepositoryScanResult?
    let onChange: (Repository) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Enabled", isOn: enabledBinding)
                .labelsHidden()
                .help("Include this repository in scans.")

            VStack(alignment: .leading, spacing: 2) {
                Text(repository.name)
                    .fontWeight(.medium)
                Text(repository.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let error = result?.error {
                    Label(error.shortDescription, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                } else if let result {
                    Text("\(result.matchingCommits) of your commits · \(result.newCommits.count) new")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Picker("Scope", selection: scopeBinding) {
                ForEach(ProjectScope.allCases) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }
            .labelsHidden()
            .fixedSize()
            .help("Commits from this repository count as \(repository.scope.displayName.lowercased()).")

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .help("Remove this repository. Commits already imported are kept.")
            .accessibilityLabel("Remove \(repository.name)")
        }
        .padding(.vertical, 4)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { repository.enabled },
            set: { newValue in
                var updated = repository
                updated.enabled = newValue
                onChange(updated)
            }
        )
    }

    private var scopeBinding: Binding<ProjectScope> {
        Binding(
            get: { repository.scope },
            set: { newValue in
                var updated = repository
                updated.scope = newValue
                onChange(updated)
            }
        )
    }
}
