import Foundation
import Testing
@testable import Velocity

/// Builds `git log` output the way git would, so the fixtures cannot drift from
/// the format the scanner actually asks for.
private func logOutput(_ records: [(sha: String, date: String, email: String, message: String)]) -> String {
    let unit = String(GitCommitParser.fieldSeparator)
    let record = String(GitCommitParser.recordSeparator)
    return records
        .map { "\($0.sha)\(unit)\($0.date)\(unit)\($0.email)\(unit)\($0.message)\(record)" }
        .joined()
}

struct GitCommitParserTests {
    private let parser = GitCommitParser()

    @Test func parsesEveryField() throws {
        let output = logOutput([
            ("a1b2c3d4", "2026-09-01T10:30:00+05:45", "dev@example.com", "feat: add authentication"),
        ])

        let commits = parser.parse(output, repositoryPath: "/tmp/repo")

        #expect(commits.count == 1)
        let commit = try #require(commits.first)
        #expect(commit.id == "a1b2c3d4")
        #expect(commit.authorEmail == "dev@example.com")
        #expect(commit.message == "feat: add authentication")
        #expect(commit.repositoryPath == "/tmp/repo")
        #expect(commit.timestamp == ISO8601DateFormatter().date(from: "2026-09-01T04:45:00Z"))
    }

    @Test func keepsMultiLineMessagesAndUsesTheFirstLineAsTheSubject() throws {
        let output = logOutput([
            ("sha1", "2026-09-01T10:30:00Z", "dev@example.com",
             "feat: add authentication\n\nWith a longer body\nacross several lines."),
        ])

        let commit = try #require(parser.parse(output, repositoryPath: "/tmp/repo").first)

        #expect(commit.subject == "feat: add authentication")
        #expect(commit.message.contains("across several lines."))
    }

    @Test func parsesSeveralCommitsInOrder() {
        let output = logOutput([
            ("sha1", "2026-09-03T10:00:00Z", "dev@example.com", "third"),
            ("sha2", "2026-09-02T10:00:00Z", "dev@example.com", "second"),
            ("sha3", "2026-09-01T10:00:00Z", "dev@example.com", "first"),
        ])

        #expect(parser.parse(output, repositoryPath: "/tmp/repo").map(\.id) == ["sha1", "sha2", "sha3"])
    }

    @Test func toleratesMessagesContainingSeparatorLookalikes() throws {
        // A commit message may contain anything printable, including the text a
        // naive delimiter would have used.
        let output = logOutput([
            ("sha1", "2026-09-01T10:00:00Z", "dev@example.com", "fix: handle | pipes ; semicolons and \"quotes\""),
        ])

        let commit = try #require(parser.parse(output, repositoryPath: "/tmp/repo").first)
        #expect(commit.message == "fix: handle | pipes ; semicolons and \"quotes\"")
    }

    @Test func skipsMalformedRecordsRatherThanFailingTheWholeScan() {
        let unit = String(GitCommitParser.fieldSeparator)
        let record = String(GitCommitParser.recordSeparator)
        let output = """
        sha1\(unit)2026-09-01T10:00:00Z\(unit)dev@example.com\(unit)good\(record)\
        truncated-record\(record)\
        sha3\(unit)not-a-date\(unit)dev@example.com\(unit)bad date\(record)\
        sha4\(unit)2026-09-02T10:00:00Z\(unit)dev@example.com\(unit)also good\(record)
        """

        #expect(parser.parse(output, repositoryPath: "/tmp/repo").map(\.id) == ["sha1", "sha4"])
    }

    @Test func emptyOutputYieldsNoCommits() {
        #expect(parser.parse("", repositoryPath: "/tmp/repo").isEmpty)
    }

    @Test func logArgumentsExcludeMerges() {
        #expect(GitCommitParser.logArguments().contains("--no-merges"))
    }
}
