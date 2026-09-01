import Foundation
import Testing
@testable import Velocity

@MainActor
struct QuickLogTests {
    @Test func loggingCreatesAManualItemInTheFeed() throws {
        let store = VelocityStore()

        let item = try #require(store.logManualItem(title: "Shipped the launch", scope: .work, weight: .epic))

        #expect(store.shippedItems.count == 1)
        #expect(item.source == .manual)
        #expect(item.commitSHA == nil)
        #expect(item.repositoryPath == nil)
        #expect(item.scope == .work)
        #expect(item.weight == .epic)
        #expect(item.points == 5)
        #expect(UUID(uuidString: item.id) != nil)
    }

    @Test func bothScopesAreRecorded() {
        let store = VelocityStore()
        store.logManualItem(title: "Work thing", scope: .work, weight: .core)
        store.logManualItem(title: "Personal thing", scope: .personal, weight: .minor)

        #expect(store.items(matching: .work).map(\.title) == ["Work thing"])
        #expect(store.items(matching: .personal).map(\.title) == ["Personal thing"])
        #expect(store.items(matching: .all).count == 2)
    }

    @Test(arguments: [ImpactWeight.minor, .core, .epic])
    func everyImpactLevelCanBeChosen(weight: ImpactWeight) throws {
        let store = VelocityStore()
        let item = try #require(store.logManualItem(title: "Something", scope: .work, weight: weight))
        #expect(item.weight == weight)
        #expect(store.pointsShippedToday() == weight.points)
    }

    @Test func blankTitlesAreRejected() {
        let store = VelocityStore()

        #expect(store.logManualItem(title: "", scope: .work, weight: .core) == nil)
        #expect(store.logManualItem(title: "   \n ", scope: .work, weight: .core) == nil)
        #expect(store.shippedItems.isEmpty)
    }

    @Test func titlesAreTrimmed() throws {
        let store = VelocityStore()
        let item = try #require(store.logManualItem(title: "  Wrote the notes  ", scope: .work, weight: .minor))
        #expect(item.title == "Wrote the notes")
    }

    @Test func aNewEntryAppearsAtTheTopOfTheFeed() throws {
        let store = VelocityStore()
        store.add(
            ShippedItem(
                id: "old", title: "Yesterday", timestamp: .now.addingTimeInterval(-86_400),
                scope: .work, weight: .core, source: .manual
            )
        )

        store.logManualItem(title: "Just now", scope: .work, weight: .core)

        #expect(store.shippedItems.first?.title == "Just now")
    }

    @Test func manualEntriesCountTowardsTodaysTotal() {
        let store = VelocityStore()
        store.logManualItem(title: "One", scope: .work, weight: .epic)
        store.logManualItem(title: "Two", scope: .personal, weight: .core)

        #expect(store.pointsShippedToday() == 8)
        #expect(store.itemsShippedToday().count == 2)
    }

    @Test func deletingRemovesItFromEveryDerivedNumber() throws {
        let store = VelocityStore()
        let item = try #require(store.logManualItem(title: "Mistake", scope: .work, weight: .epic))
        #expect(store.pointsShippedToday() == 5)

        store.delete(id: item.id)

        #expect(store.shippedItems.isEmpty)
        #expect(store.pointsShippedToday() == 0)
        #expect(store.items(matching: .work).isEmpty)
    }
}

@MainActor
struct ItemOverrideTests {
    @Test func impactCanBeChangedAfterTheFact() throws {
        let store = VelocityStore()
        let item = try #require(store.logManualItem(title: "Undersold", scope: .work, weight: .minor))
        #expect(store.pointsShippedToday() == 1)

        store.setWeight(.epic, forItemWith: item.id)

        #expect(store.shippedItems.first?.weight == .epic)
        #expect(store.pointsShippedToday() == 5)
    }

    @Test func aScoredGitCommitCanBeOverridden() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await repo.commit("fix: a one-line change that took a week")
        try await store.addRepository(path: repo.path, scope: .personal)
        store.settings.gitAuthorEmail = "dev@example.com"

        await store.scanRepositories()
        let imported = try #require(store.shippedItems.first)
        #expect(imported.weight == .minor)   // scored from the message

        store.setWeight(.core, forItemWith: imported.id)

        #expect(store.shippedItems.first?.weight == .core)
        #expect(store.shippedItems.first?.commitSHA == imported.commitSHA)
    }

    @Test func scopeCanBeChangedAfterTheFact() throws {
        let store = VelocityStore()
        let item = try #require(store.logManualItem(title: "Wrong bucket", scope: .personal, weight: .core))

        store.setScope(.work, forItemWith: item.id)

        #expect(store.items(matching: .work).count == 1)
        #expect(store.items(matching: .personal).isEmpty)
    }

    @Test func overridingAnUnknownItemChangesNothing() {
        let store = VelocityStore()
        store.logManualItem(title: "Untouched", scope: .work, weight: .core)

        store.setWeight(.epic, forItemWith: "no-such-id")

        #expect(store.shippedItems.first?.weight == .core)
    }
}

@MainActor
struct ScannedCommitScoringTests {
    @Test func scannedCommitsAreScoredFromTheirMessages() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await repo.commit("deploy: ship v1")
        try await repo.commit("feat: add the thing")
        try await repo.commit("chore: tidy up")
        try await store.addRepository(path: repo.path, scope: .work)
        store.settings.gitAuthorEmail = "dev@example.com"

        await store.scanRepositories()

        let byTitle = Dictionary(uniqueKeysWithValues: store.shippedItems.map { ($0.title, $0.weight) })
        #expect(byTitle["deploy: ship v1"] == .epic)
        #expect(byTitle["feat: add the thing"] == .core)
        #expect(byTitle["chore: tidy up"] == .minor)
        #expect(store.pointsShippedToday() == 0)   // commits are dated in the past
    }

    @Test func rescanningDoesNotDuplicateOrRescoreImportedCommits() async throws {
        let store = VelocityStore(scanner: try GitScanner.locate())
        let repo = try TestRepository(runner: try GitRunner.locate())
        try await repo.initialize()
        try await repo.commit("feat: once")
        try await store.addRepository(path: repo.path, scope: .work)
        store.settings.gitAuthorEmail = "dev@example.com"

        await store.scanRepositories()
        #expect(store.shippedItems.count == 1)

        // An override must survive a rescan, not be reset by it.
        let id = try #require(store.shippedItems.first?.id)
        store.setWeight(.epic, forItemWith: id)

        await store.scanRepositories()

        #expect(store.shippedItems.count == 1)
        #expect(store.lastImportCount == 0)
        #expect(store.shippedItems.first?.weight == .epic)
    }
}
