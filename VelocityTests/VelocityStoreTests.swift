import Foundation
import Testing
@testable import Velocity

@MainActor
struct VelocityStoreTests {
    private func item(
        id: String = UUID().uuidString,
        title: String = "Item",
        daysAgo: Int = 0,
        scope: ProjectScope = .personal,
        weight: ImpactWeight = .core
    ) -> ShippedItem {
        let timestamp = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        return ShippedItem(
            id: id,
            title: title,
            timestamp: timestamp,
            scope: scope,
            weight: weight,
            source: .manual
        )
    }

    @Test func addingTheSameIDTwiceKeepsOneItem() {
        let store = VelocityStore()
        store.add(item(id: "sha-a", title: "First"))
        store.add(item(id: "sha-a", title: "First, rescanned"))

        #expect(store.shippedItems.count == 1)
        #expect(store.shippedItems.first?.title == "First, rescanned")
    }

    @Test func feedIsNewestFirst() {
        let store = VelocityStore()
        store.add(contentsOf: [
            item(id: "old", title: "Old", daysAgo: 3),
            item(id: "new", title: "New", daysAgo: 0),
            item(id: "mid", title: "Mid", daysAgo: 1),
        ])

        #expect(store.shippedItems.map(\.id) == ["new", "mid", "old"])
    }

    @Test func scopeFilterNarrowsTheFeed() {
        let store = VelocityStore()
        store.add(contentsOf: [
            item(id: "w", scope: .work),
            item(id: "p", scope: .personal),
        ])

        #expect(store.items(matching: .all).count == 2)
        #expect(store.items(matching: .work).map(\.id) == ["w"])
        #expect(store.items(matching: .personal).map(\.id) == ["p"])
    }

    @Test func todayPointsCountOnlyTodaysItems() {
        let store = VelocityStore()
        store.add(contentsOf: [
            item(id: "today-1", weight: .core),
            item(id: "today-2", weight: .epic),
            item(id: "yesterday", daysAgo: 1, weight: .epic),
        ])

        #expect(store.pointsShippedToday() == 8)
        #expect(store.itemsShippedToday().count == 2)
    }

    @Test func deleteRemovesTheItem() {
        let store = VelocityStore()
        store.add(item(id: "gone"))
        store.delete(id: "gone")

        #expect(store.shippedItems.isEmpty)
    }

    @Test func monthlyVelocitiesAccumulateThroughToday() {
        let store = VelocityStore()
        store.add(contentsOf: [
            item(id: "a", daysAgo: 2, weight: .core),
            item(id: "b", daysAgo: 1, weight: .epic),
            item(id: "c", daysAgo: 0, weight: .minor),
        ])

        let series = store.monthlyVelocities()
        #expect(series.count == store.daysElapsedThisMonth())
        #expect(series.last?.cumulativePoints == 9)
        #expect(series.last?.day == store.daysElapsedThisMonth())
    }

    @Test func monthlyVelocitiesRespectTheScopeFilter() {
        let store = VelocityStore()
        store.add(contentsOf: [
            item(id: "w", scope: .work, weight: .epic),
            item(id: "p", scope: .personal, weight: .minor),
        ])
        store.scopeFilter = .work

        #expect(store.monthlyVelocities().last?.cumulativePoints == 5)
    }

    @Test func averageDailyVelocityDividesByDaysElapsed() {
        let store = VelocityStore()
        store.add(item(id: "a", daysAgo: 0, weight: .core))

        let expected = 3.0 / Double(store.daysElapsedThisMonth())
        #expect(store.averageDailyVelocity() == expected)
    }

    @Test func itemsShippedOnDayFiltersByDayOfMonthAndScope() {
        let store = VelocityStore()
        store.add(contentsOf: [
            item(id: "today", daysAgo: 0, scope: .personal),
            item(id: "yesterday", daysAgo: 1, scope: .personal),
        ])
        let today = store.daysElapsedThisMonth()

        #expect(store.items(shippedOnDay: today).map(\.id) == ["today"])
    }

    @Test func snapshotRoundTripsThroughJSON() throws {
        let store = VelocityStore()
        store.add(item(id: "sha-a", title: "feat: thing", weight: .core))
        store.addRepository(Repository(name: "velocity", path: "/tmp/velocity", scope: .personal))
        store.settings.targetDailyVelocity = 3.5
        store.settings.gitAuthorEmail = "dev@example.com"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(store.snapshot)
        let decoded = try decoder.decode(VelocityData.self, from: data)

        #expect(decoded.version == VelocityData.currentVersion)
        #expect(decoded.items.map(\.id) == ["sha-a"])
        #expect(decoded.repositories.map(\.path) == ["/tmp/velocity"])
        #expect(decoded.settings.targetDailyVelocity == 3.5)
        #expect(decoded.settings.gitAuthorEmail == "dev@example.com")
    }
}

struct VelocityGoalTests {
    @Test func monthlyTargetUsesFullPrecision() {
        let goal = VelocityGoal(targetDailyVelocity: 2.5, daysInMonth: 31)
        #expect(goal.monthlyTarget == 77.5)
    }

    @Test func cumulativeTargetClampsToTheMonth() {
        let goal = VelocityGoal(targetDailyVelocity: 2.0, daysInMonth: 30)
        #expect(goal.cumulativeTarget(throughDay: 0) == 0)
        #expect(goal.cumulativeTarget(throughDay: 15) == 30)
        #expect(goal.cumulativeTarget(throughDay: 99) == 60)
    }
}

struct CommitTests {
    @Test func subjectIsTheFirstLine() {
        let commit = Commit(
            id: "abc123",
            message: "feat: add auth\n\nLonger body text.",
            timestamp: .now,
            repositoryPath: "/tmp/repo",
            authorEmail: "dev@example.com"
        )
        #expect(commit.subject == "feat: add auth")
    }

    @Test func shippedItemFromCommitInheritsTheSHAAsIdentity() {
        let commit = Commit(
            id: "abc123",
            message: "feat: add auth",
            timestamp: .now,
            repositoryPath: "/tmp/repo",
            authorEmail: "dev@example.com"
        )
        let item = ShippedItem.fromCommit(commit, scope: .work, weight: .core)

        #expect(item.id == "abc123")
        #expect(item.commitSHA == "abc123")
        #expect(item.source == .git)
        #expect(item.repositoryPath == "/tmp/repo")
    }
}
