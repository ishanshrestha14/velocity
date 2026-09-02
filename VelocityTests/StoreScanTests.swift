import Foundation
import Testing
@testable import Velocity

@MainActor
struct StoreRepositoryTests {
    private func makeStore() throws -> VelocityStore {
        VelocityStore(scanner: try GitScanner.locate())
    }

    @Test func addingARepositoryUsesTheFolderNameAndValidatesIt() async throws {
        let store = try makeStore()
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()

        try await store.addRepository(path: repo.path, scope: .work)

        #expect(store.repositories.count == 1)
        #expect(store.repositories.first?.name == repo.url.lastPathComponent)
        #expect(store.repositories.first?.scope == .work)
        #expect(store.repositories.first?.enabled == true)
    }

    @Test func addingAFolderThatIsNotARepositoryFailsAndAddsNothing() async throws {
        let store = try makeStore()
        let temp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "VelocityPlain-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let path = temp.path(percentEncoded: false)

        await #expect(throws: GitError.notARepository(path: path)) {
            try await store.addRepository(path: path, scope: .work)
        }
        #expect(store.repositories.isEmpty)
    }

    @Test func addingTheSamePathTwiceKeepsOneRepository() async throws {
        let store = try makeStore()
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()

        try await store.addRepository(path: repo.path, scope: .work)
        try await store.addRepository(path: repo.path, scope: .personal)

        #expect(store.repositories.count == 1)
        #expect(store.repositories.first?.scope == .work)
    }

    @Test func scopeAndEnabledCanBeChanged() {
        let store = VelocityStore()
        let repository = Repository(name: "r", path: "/tmp/r", scope: .personal)
        store.addRepository(repository)

        var updated = repository
        updated.scope = .work
        updated.enabled = false
        store.updateRepository(updated)

        #expect(store.repositories.first?.scope == .work)
        #expect(store.repositories.first?.enabled == false)
    }

    @Test func removingARepositoryDropsIt() {
        let store = VelocityStore()
        let repository = Repository(name: "r", path: "/tmp/r", scope: .personal)
        store.addRepository(repository)
        store.removeRepository(id: repository.id)

        #expect(store.repositories.isEmpty)
    }

    @Test func scanningNeedsAnEmailARepositoryAndGit() async throws {
        let store = try makeStore()
        #expect(store.canScan == false)   // no email, no repositories

        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await store.addRepository(path: repo.path, scope: .personal)
        #expect(store.canScan == false)   // still no email

        store.settings.gitAuthorEmail = "dev@example.com"
        #expect(store.canScan)
    }
}

@MainActor
struct StoreScanTests {
    @Test func scanningFindsCommitsAndReportsPerRepository() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await repo.commit("feat: one")
        try await repo.commit("fix: two")

        try await store.addRepository(path: repo.path, scope: .work)
        store.settings.gitAuthorEmail = "dev@example.com"

        await store.scanRepositories()

        #expect(store.isScanning == false)
        #expect(store.scanError == nil)
        #expect(store.lastImportCount == 2)
        #expect(store.shippedItems.count == 2)
        #expect(store.shippedItems.allSatisfy { $0.scope == .work })
        #expect(store.shippedItems.allSatisfy { $0.source == .git })
        #expect(store.lastScanReport?.scannedRepositoryCount == 1)
    }

    @Test func commitsAlreadyInTheFeedAreNotOfferedAgain() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        let firstSHA = try await repo.commit("feat: already imported")
        try await repo.commit("feat: brand new")

        try await store.addRepository(path: repo.path, scope: .personal)
        store.settings.gitAuthorEmail = "dev@example.com"

        // Stand in for a previous import: the SHA is the item's id.
        store.add(
            ShippedItem(
                id: firstSHA,
                title: "feat: already imported",
                timestamp: .now,
                scope: .personal,
                weight: .core,
                source: .git,
                repositoryPath: repo.path,
                commitSHA: firstSHA
            )
        )

        await store.scanRepositories()

        #expect(store.lastImportCount == 1)
        #expect(store.shippedItems.count == 2)
        #expect(store.shippedItems.map(\.title).contains("feat: brand new"))
    }

    @Test func scanningWithoutAnEmailReportsRatherThanRunning() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await repo.commit("feat: one")
        try await store.addRepository(path: repo.path, scope: .personal)

        await store.scanRepositories()

        #expect(store.scanError != nil)
        #expect(store.shippedItems.isEmpty)
        #expect(store.lastScanReport == nil)
    }

    @Test func aBrokenRepositoryDoesNotStopTheGoodOne() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await repo.commit("feat: counted")

        try await store.addRepository(path: repo.path, scope: .personal)
        store.addRepository(Repository(name: "gone", path: "/nonexistent/velocity", scope: .work))
        store.settings.gitAuthorEmail = "dev@example.com"

        await store.scanRepositories()

        #expect(store.shippedItems.count == 1)
        #expect(store.lastScanReport?.failedRepositories.count == 1)
    }

    @Test func disabledRepositoriesAreNotScanned() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await repo.commit("feat: ignored")

        try await store.addRepository(path: repo.path, scope: .personal)
        var repository = try #require(store.repositories.first)
        repository.enabled = false
        store.updateRepository(repository)
        store.settings.gitAuthorEmail = "dev@example.com"

        #expect(store.canScan == false)
        await store.scanRepositories()
        #expect(store.shippedItems.isEmpty)
    }
}

@MainActor
struct AddRepositoryOutcomeTests {
    @Test func addingReportsWhatHappenedToEachPath() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()

        let first = try await store.addRepository(path: repo.path, scope: .work)
        guard case .added(let repository) = first else {
            Issue.record("expected .added, got \(first)")
            return
        }
        #expect(repository.scope == .work)

        // The same folder again is a duplicate, not a second repository and not
        // an error — adding a batch that overlaps an existing one is ordinary.
        let second = try await store.addRepository(path: repo.path, scope: .personal)
        #expect(second == .alreadyPresent)
        #expect(store.repositories.count == 1)
    }

    @Test func theChosenScopeIsAppliedToEachAddedRepository() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let runner = try GitRunner.locate()
        let a = try TestRepository(runner: runner)
        let b = try TestRepository(runner: runner)
        try await a.initialize()
        try await b.initialize()

        try await store.addRepository(path: a.path, scope: .work)
        try await store.addRepository(path: b.path, scope: .work)

        #expect(store.repositories.count == 2)
        #expect(store.repositories.allSatisfy { $0.scope == .work })
    }

    @Test func addingABatchKeepsTheGoodOnesWhenOneIsNotARepository() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        let plain = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "VelocityPlainBatch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: plain) }

        var failures = 0
        for path in [plain.path(percentEncoded: false), repo.path] {
            do {
                try await store.addRepository(path: path, scope: .personal)
            } catch {
                failures += 1
            }
        }

        #expect(failures == 1)
        #expect(store.repositories.map(\.path) == [repo.path])
    }
}

struct AddSummaryTests {
    @Test func staysQuietForASingleCleanAdd() {
        #expect(RepositorySettingsView.summary(added: 1, duplicates: 0, failed: 0) == nil)
    }

    @Test func reportsWhatWasSkipped() {
        #expect(RepositorySettingsView.summary(added: 3, duplicates: 0, failed: 0) == "Added 3 repositories")
        #expect(RepositorySettingsView.summary(added: 2, duplicates: 1, failed: 1)
                == "Added 2 repositories · 1 already added · 1 skipped")
        #expect(RepositorySettingsView.summary(added: 0, duplicates: 1, failed: 0) == "1 already added")
        #expect(RepositorySettingsView.summary(added: 1, duplicates: 0, failed: 2)
                == "Added 1 repository · 2 skipped")
    }
}
