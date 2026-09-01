import Foundation
import Testing
@testable import Velocity

/// A real Git repository in a temporary directory.
///
/// The scanner's whole job is talking to git, so the tests talk to git too —
/// a hand-written fake would only prove the fake matches itself.
final class TestRepository {
    let url: URL
    private let runner: GitRunner

    init(runner: GitRunner) throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "VelocityGitTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        self.runner = runner
    }

    var path: String { url.path(percentEncoded: false) }

    func initialize() async throws {
        _ = try await runner.runExpectingSuccess(["init", "--initial-branch=main"], in: url)
        _ = try await runner.runExpectingSuccess(["config", "user.name", "Test Author"], in: url)
        _ = try await runner.runExpectingSuccess(["config", "user.email", "dev@example.com"], in: url)
        _ = try await runner.runExpectingSuccess(["config", "commit.gpgsign", "false"], in: url)
    }

    /// Commit a change, optionally as somebody else.
    @discardableResult
    func commit(
        _ message: String,
        author: String = "Test Author <dev@example.com>",
        date: String = "2026-09-01T10:00:00+00:00"
    ) async throws -> String {
        let file = url.appending(path: "file-\(UUID().uuidString).txt")
        try message.write(to: file, atomically: true, encoding: .utf8)
        _ = try await runner.runExpectingSuccess(["add", "-A"], in: url)
        _ = try await runner.runExpectingSuccess(
            [
                "-c", "user.name=Test Author",
                "commit",
                "--author=\(author)",
                "--date=\(date)",
                "-m", message,
            ],
            in: url
        )
        return try await runner
            .runExpectingSuccess(["rev-parse", "HEAD"], in: url)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func repository(scope: ProjectScope = .personal, enabled: Bool = true) -> Repository {
        Repository(name: url.lastPathComponent, path: path, scope: scope, enabled: enabled)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

struct GitScannerTests {
    private func makeScanner() throws -> GitScanner {
        try GitScanner.locate()
    }

    @Test func gitIsAvailableOnThisMachine() async throws {
        let runner = try GitRunner.locate()
        let version = try await runner.runExpectingSuccess(["--version"])
        #expect(version.hasPrefix("git version"))
    }

    @Test func discoversCommitsAndPreservesTheSHA() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        let firstSHA = try await repo.commit("feat: add authentication")
        let secondSHA = try await repo.commit("fix: correct a typo")

        let result = await scanner.scan(
            repository: repo.repository(),
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(result.error == nil)
        #expect(result.matchingCommits == 2)
        let shas = Set(result.newCommits.map(\.id))
        #expect(shas == [firstSHA, secondSHA])
        // The id is the real SHA, not a derived or truncated one.
        #expect(result.newCommits.allSatisfy { $0.commit.sha.count == 40 })
    }

    @Test func onlyImportsCommitsByTheConfiguredAuthor() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        try await repo.commit("feat: mine")
        try await repo.commit("feat: theirs", author: "Someone Else <colleague@example.com>")

        let result = await scanner.scan(
            repository: repo.repository(),
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(result.matchingCommits == 1)
        #expect(result.newCommits.map(\.commit.subject) == ["feat: mine"])
    }

    @Test func authorMatchIsExactNotSubstring() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        try await repo.commit("feat: mine")
        // An address that contains the configured one must not match.
        try await repo.commit("feat: not mine", author: "Impostor <notdev@example.com.evil.test>")

        let result = await scanner.scan(
            repository: repo.repository(),
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(result.newCommits.map(\.commit.subject) == ["feat: mine"])
    }

    @Test func authorMatchIgnoresCase() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        try await repo.commit("feat: mine", author: "Test Author <Dev@Example.com>")

        let result = await scanner.scan(
            repository: repo.repository(),
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(result.matchingCommits == 1)
    }

    @Test func rescanningFindsNothingNew() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        try await repo.commit("feat: one")
        try await repo.commit("feat: two")

        let first = await scanner.scan(
            repository: repo.repository(), authorEmail: "dev@example.com", knownCommitSHAs: []
        )
        #expect(first.newCommits.count == 2)

        // Second pass with the first pass's SHAs already known.
        let known = Set(first.newCommits.map(\.id))
        let second = await scanner.scan(
            repository: repo.repository(), authorEmail: "dev@example.com", knownCommitSHAs: known
        )

        #expect(second.matchingCommits == 2)
        #expect(second.newCommits.isEmpty)
    }

    @Test func commitsInheritTheirRepositoryScope() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        try await repo.commit("feat: work thing")

        let result = await scanner.scan(
            repository: repo.repository(scope: .work),
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(result.newCommits.allSatisfy { $0.scope == .work })
    }

    @Test func mergeCommitsAreNotCounted() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        try await repo.commit("feat: base")
        let runner = scanner.runner
        _ = try await runner.runExpectingSuccess(["checkout", "-b", "side"], in: repo.url)
        try await repo.commit("feat: on the branch")
        _ = try await runner.runExpectingSuccess(["checkout", "main"], in: repo.url)
        try await repo.commit("feat: on main")
        _ = try await runner.runExpectingSuccess(
            ["-c", "user.email=dev@example.com", "-c", "user.name=Test Author",
             "merge", "--no-ff", "-m", "Merge branch 'side'", "side"],
            in: repo.url
        )

        let result = await scanner.scan(
            repository: repo.repository(), authorEmail: "dev@example.com", knownCommitSHAs: []
        )

        #expect(result.matchingCommits == 3)
        #expect(!result.newCommits.contains { $0.commit.subject.hasPrefix("Merge branch") })
    }

    // MARK: - Failure handling

    @Test func aMissingPathReportsNotFoundWithoutThrowing() async throws {
        let scanner = try makeScanner()
        let repository = Repository(name: "gone", path: "/nonexistent/velocity-test-repo", scope: .work)

        let result = await scanner.scan(
            repository: repository, authorEmail: "dev@example.com", knownCommitSHAs: []
        )

        #expect(result.error == .repositoryNotFound(path: "/nonexistent/velocity-test-repo"))
        #expect(result.newCommits.isEmpty)
    }

    @Test func aFolderThatIsNotARepositoryIsReportedAsSuch() async throws {
        let scanner = try makeScanner()
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "VelocityNotARepo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let path = temp.path(percentEncoded: false)
        let result = await scanner.scan(
            repository: Repository(name: "plain", path: path, scope: .work),
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(result.error == .notARepository(path: path))
    }

    @Test func oneBadRepositoryDoesNotStopTheOthers() async throws {
        let scanner = try makeScanner()
        let good = try TestRepository(runner: scanner.runner)
        try await good.initialize()
        try await good.commit("feat: still counted")

        let report = await scanner.scan(
            repositories: [
                Repository(name: "missing", path: "/nonexistent/one", scope: .work),
                good.repository(),
                Repository(name: "missing-too", path: "/nonexistent/two", scope: .personal),
            ],
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(report.results.count == 3)
        #expect(report.failedRepositories.count == 2)
        #expect(report.scannedRepositoryCount == 1)
        #expect(report.newCommits.map(\.commit.subject) == ["feat: still counted"])
    }

    @Test func disabledRepositoriesAreSkipped() async throws {
        let scanner = try makeScanner()
        let repo = try TestRepository(runner: scanner.runner)
        try await repo.initialize()
        try await repo.commit("feat: ignored")

        let report = await scanner.scan(
            repositories: [repo.repository(enabled: false)],
            authorEmail: "dev@example.com",
            knownCommitSHAs: []
        )

        #expect(report.results.isEmpty)
        #expect(report.newCommits.isEmpty)
    }

    @Test func resultsKeepTheConfiguredOrder() async throws {
        let scanner = try makeScanner()
        let first = try TestRepository(runner: scanner.runner)
        let second = try TestRepository(runner: scanner.runner)
        try await first.initialize()
        try await second.initialize()
        try await first.commit("feat: a")
        try await second.commit("feat: b")

        let configured = [first.repository(), second.repository()]
        let report = await scanner.scan(
            repositories: configured, authorEmail: "dev@example.com", knownCommitSHAs: []
        )

        #expect(report.results.map(\.repositoryID) == configured.map(\.id))
    }
}

struct GitRepositoryValidatorTests {
    @Test func acceptsARealRepository() async throws {
        let runner = try GitRunner.locate()
        let repo = try TestRepository(runner: runner)
        try await repo.initialize()

        try await GitRepositoryValidator(runner: runner).validate(path: repo.path)
    }

    @Test func rejectsAFile() async throws {
        let runner = try GitRunner.locate()
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "VelocityFile-\(UUID().uuidString).txt")
        try "not a folder".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }

        let path = file.path(percentEncoded: false)
        await #expect(throws: GitError.pathIsNotADirectory(path: path)) {
            try await GitRepositoryValidator(runner: runner).validate(path: path)
        }
    }

    @Test func suggestsTheFolderNameAsADisplayName() {
        #expect(GitRepositoryValidator.suggestedName(for: "/Users/example/Code/velocity") == "velocity")
    }
}
