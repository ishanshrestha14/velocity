import Foundation

/// Reads commits out of the configured repositories.
///
/// Repositories are scanned concurrently and independently: one that has been
/// deleted, or is not a repository at all, records its error and leaves the rest
/// of the scan untouched.
struct GitScanner: Sendable {
    let runner: GitRunner
    let parser = GitCommitParser()
    private let validator: GitRepositoryValidator

    init(runner: GitRunner, fileManager: FileManager = .default) {
        self.runner = runner
        self.validator = GitRepositoryValidator(runner: runner, fileManager: fileManager)
    }

    static func locate(fileManager: FileManager = .default) throws -> GitScanner {
        GitScanner(runner: try GitRunner.locate(fileManager: fileManager), fileManager: fileManager)
    }

    /// Scan every enabled repository.
    ///
    /// - Parameters:
    ///   - authorEmail: only commits with exactly this author email are kept.
    ///   - knownCommitSHAs: SHAs already imported, which is what makes repeated
    ///     scans idempotent.
    func scan(
        repositories: [Repository],
        authorEmail: String,
        knownCommitSHAs: Set<String>,
        now: Date = .now
    ) async -> ScanReport {
        let startedAt = now
        let enabled = repositories.filter(\.enabled)

        var results: [RepositoryScanResult] = []
        await withTaskGroup(of: RepositoryScanResult.self) { group in
            for repository in enabled {
                group.addTask {
                    await scan(
                        repository: repository,
                        authorEmail: authorEmail,
                        knownCommitSHAs: knownCommitSHAs
                    )
                }
            }
            for await result in group {
                results.append(result)
            }
        }

        // Task groups complete out of order; keep the configured order so the
        // UI does not reshuffle between scans.
        let order = Dictionary(uniqueKeysWithValues: enabled.enumerated().map { ($0.element.id, $0.offset) })
        results.sort { (order[$0.repositoryID] ?? 0) < (order[$1.repositoryID] ?? 0) }

        return ScanReport(startedAt: startedAt, finishedAt: .now, results: results)
    }

    func scan(
        repository: Repository,
        authorEmail: String,
        knownCommitSHAs: Set<String>
    ) async -> RepositoryScanResult {
        func failure(_ error: GitError) -> RepositoryScanResult {
            RepositoryScanResult(
                repositoryID: repository.id,
                repositoryName: repository.name,
                repositoryPath: repository.path,
                matchingCommits: 0,
                newCommits: [],
                error: error
            )
        }

        do {
            try await validator.validate(path: repository.path)
        } catch let error as GitError {
            return failure(error)
        } catch {
            return failure(.commandFailed(status: -1, message: error.localizedDescription))
        }

        let output: String
        do {
            output = try await runner.runExpectingSuccess(
                GitCommitParser.logArguments(),
                in: repository.url
            )
        } catch let error as GitError {
            return failure(error)
        } catch {
            return failure(.commandFailed(status: -1, message: error.localizedDescription))
        }

        let commits = parser.parse(output, repositoryPath: repository.path)

        // Exact, case-insensitive match rather than git's --author, which is a
        // regex substring test: it would treat a '+' in an address as syntax and
        // would match a colleague whose address contains the configured one.
        let wanted = authorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let mine = commits.filter { $0.authorEmail.lowercased() == wanted }

        let new = mine
            .filter { !knownCommitSHAs.contains($0.id) }
            .map { DiscoveredCommit(commit: $0, scope: repository.scope) }

        return RepositoryScanResult(
            repositoryID: repository.id,
            repositoryName: repository.name,
            repositoryPath: repository.path,
            matchingCommits: mine.count,
            newCommits: new,
            error: nil
        )
    }
}
