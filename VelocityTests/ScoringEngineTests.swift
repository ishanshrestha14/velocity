import Foundation
import Testing
@testable import Velocity

struct ScoringEngineTests {
    private let engine = ScoringEngine()

    // MARK: - The table from the README

    @Test(arguments: [
        "feat!: rewrite the sync engine",
        "breaking: drop the v1 API",
        "deploy: ship v2.0 to production",
    ])
    func epicMessagesScoreFive(message: String) {
        #expect(engine.score(message: message) == .epic)
        #expect(engine.score(message: message).points == 5)
    }

    @Test(arguments: [
        "feat: add authentication",
        "refactor: extract the scoring rules",
        "db: add an index on commit_sha",
    ])
    func coreMessagesScoreThree(message: String) {
        #expect(engine.score(message: message) == .core)
        #expect(engine.score(message: message).points == 3)
    }

    @Test(arguments: [
        "fix: correct the off-by-one",
        "docs: write the readme",
        "style: reformat the views",
        "chore: bump dependencies",
        "cleanup old migrations",
    ])
    func minorMessagesScoreOne(message: String) {
        #expect(engine.score(message: message) == .minor)
        #expect(engine.score(message: message).points == 1)
    }

    // MARK: - Strongest rule wins

    @Test func aBreakingMarkerOutranksTheType() {
        // refactor is normally core; breaking makes it a launch.
        #expect(engine.score(message: "refactor!: change every public signature") == .epic)
        #expect(engine.score(message: "fix!: change the default behaviour") == .epic)
        #expect(engine.score(message: "chore!: drop support for macOS 14") == .epic)
    }

    @Test func aScopeDoesNotChangeTheScore() {
        #expect(engine.score(message: "feat(auth): add sign in") == .core)
        #expect(engine.score(message: "feat(auth)!: replace the token format") == .epic)
        #expect(engine.score(message: "fix(dashboard): correct the total") == .minor)
    }

    // MARK: - Substring accidents

    @Test(arguments: [
        "fixture: add test data",
        "deployment notes: how releases work",
        "database: rename a column",
        "features: list what we support",
        "documentation: expand the guide",
    ])
    func lookalikeTypesDoNotMatchTheRealOnes(message: String) {
        // Each of these contains a scoring keyword as a substring but is not
        // that type. The risk is claiming a weight it has not earned, so the
        // assertion is that it scores neither core nor epic.
        let score = engine.score(message: message)
        #expect(score != .core)
        #expect(score != .epic)
        #expect(score == ScoringEngine.fallback)
    }

    // MARK: - Case and whitespace

    @Test func typesAreCaseInsensitive() {
        #expect(engine.score(message: "FEAT: add authentication") == .core)
        #expect(engine.score(message: "Deploy: ship it") == .epic)
        #expect(engine.score(message: "Feat!: rewrite") == .epic)
    }

    @Test func leadingWhitespaceIsIgnored() {
        #expect(engine.score(message: "   feat: add authentication") == .core)
    }

    // MARK: - Message shape

    @Test func onlyTheSubjectLineIsScored() {
        let message = """
        feat: add authentication

        This body mentions deploy: and breaking: but neither should count,
        because the subject is what describes the commit.
        """
        #expect(engine.score(message: message) == .core)
    }

    @Test func unknownAndEmptyMessagesFallBack() {
        #expect(engine.score(message: "made some changes") == ScoringEngine.fallback)
        #expect(engine.score(message: "wip: still working") == ScoringEngine.fallback)
        #expect(engine.score(message: "") == ScoringEngine.fallback)
        #expect(engine.score(message: "   ") == ScoringEngine.fallback)
    }

    @Test func scoringIsDeterministic() {
        let message = "feat(scoring): classify conventional commits"
        let scores = (0..<50).map { _ in engine.score(message: message) }
        #expect(Set(scores).count == 1)
    }

    // MARK: - Header parsing

    @Test func parsesHeaderComponents() {
        #expect(ScoringEngine.parseHeader("feat: x") == .init(type: "feat", isBreaking: false))
        #expect(ScoringEngine.parseHeader("feat!: x") == .init(type: "feat", isBreaking: true))
        #expect(ScoringEngine.parseHeader("feat(api): x") == .init(type: "feat", isBreaking: false))
        #expect(ScoringEngine.parseHeader("feat(api)!: x") == .init(type: "feat", isBreaking: true))
    }

    @Test func rejectsThingsThatAreNotHeaders() {
        #expect(ScoringEngine.parseHeader("just a sentence") == nil)
        #expect(ScoringEngine.parseHeader("feat add authentication") == nil)
        #expect(ScoringEngine.parseHeader(": no type") == nil)
        #expect(ScoringEngine.parseHeader("feat(unclosed: x") == nil)
    }

    // MARK: - Conversion

    @Test func scoringACommitKeepsItsIdentityAndScope() {
        let commit = Commit(
            id: "abc123",
            message: "deploy: ship v2\n\nwith a body",
            timestamp: Date(timeIntervalSince1970: 1_756_700_000),
            repositoryPath: "/tmp/repo",
            authorEmail: "dev@example.com"
        )

        let item = engine.shippedItem(for: DiscoveredCommit(commit: commit, scope: .work))

        #expect(item.id == "abc123")
        #expect(item.commitSHA == "abc123")
        #expect(item.source == .git)
        #expect(item.scope == .work)
        #expect(item.weight == .epic)
        #expect(item.title == "deploy: ship v2")
        #expect(item.timestamp == commit.timestamp)
        #expect(item.repositoryPath == "/tmp/repo")
    }
}
