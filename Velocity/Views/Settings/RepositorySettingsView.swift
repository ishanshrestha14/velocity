import AppKit
import SwiftUI

/// Manage the repositories Velocity reads.
///
/// Each row carries the scope that classifies its commits as work or personal,
/// which is what keeps that decision out of the scan itself.
struct RepositorySettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    /// Scope applied to whatever is added next. Chosen before the picker opens
    /// so adding ten repositories does not mean correcting ten rows afterwards.
    @State private var addScope: ProjectScope = .personal
    @State private var addFailures: [AddFailure] = []
    @State private var addSummary: String?
    @State private var isAdding = false

    private struct AddFailure: Identifiable {
        let id = UUID()
        let path: String
        let error: GitError

        var folderName: String { URL(fileURLWithPath: path).lastPathComponent }
    }

    private var store: VelocityStore { appEnvironment.store }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.repositories.isEmpty {
                emptyState
            } else {
                repositoryList
            }

            if let addSummary {
                Text(addSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(addFailures) { failure in
                errorRow(failure)
            }

            HStack(spacing: 10) {
                Button {
                    chooseRepositories()
                } label: {
                    Label("Add Repositories…", systemImage: "plus")
                }
                .disabled(isAdding)

                Picker("Add as", selection: $addScope) {
                    ForEach(ProjectScope.allCases) { scope in
                        Text(scope.displayName).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .help("Scope given to repositories you add. Each row can be changed afterwards.")

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

    private func errorRow(_ failure: AddFailure) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(failure.folderName) — \(failure.error.errorDescription ?? "could not be added.")")
                    .fontWeight(.semibold)
                if let suggestion = failure.error.recoverySuggestion {
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

    private func chooseRepositories() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose one or more Git repositories."

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        let paths = panel.urls.map { $0.path(percentEncoded: false) }

        isAdding = true
        addFailures = []
        addSummary = nil

        Task {
            defer { isAdding = false }
            var added = 0
            var duplicates = 0
            var failures: [AddFailure] = []

            // Each folder is judged on its own: one that is not a repository
            // must not stop the rest of the selection from being added.
            for path in paths {
                do {
                    switch try await store.addRepository(path: path, scope: addScope) {
                    case .added: added += 1
                    case .alreadyPresent: duplicates += 1
                    }
                } catch let error as GitError {
                    failures.append(AddFailure(path: path, error: error))
                } catch {
                    failures.append(
                        AddFailure(path: path, error: .commandFailed(status: -1, message: error.localizedDescription))
                    )
                }
            }

            addFailures = failures
            addSummary = Self.summary(added: added, duplicates: duplicates, failed: failures.count)
        }
    }

    /// Only worth saying anything when more than one folder was chosen, or when
    /// something was skipped.
    ///
    /// `nonisolated` because it is pure string logic with no view state —
    /// without it, `View`'s conformance infers this as `@MainActor` on some
    /// toolchains, which made it uncallable from a plain synchronous test.
    nonisolated static func summary(added: Int, duplicates: Int, failed: Int) -> String? {
        guard added + duplicates + failed > 1 || duplicates > 0 || failed > 0 else { return nil }

        var parts: [String] = []
        if added > 0 {
            parts.append("Added \(added) repositor\(added == 1 ? "y" : "ies")")
        }
        if duplicates > 0 {
            parts.append("\(duplicates) already added")
        }
        if failed > 0 {
            parts.append("\(failed) skipped")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
