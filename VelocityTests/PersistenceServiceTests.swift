import Foundation
import Testing
@testable import Velocity

/// Each test gets its own throwaway directory, so nothing here can touch the
/// real Application Support folder.
private struct TempDirectory: ~Copyable {
    let url: URL

    init() throws {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appending(path: "VelocityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    var paths: VelocityPaths { VelocityPaths(root: url) }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

private func sampleData() -> VelocityData {
    VelocityData(
        items: [
            ShippedItem(
                id: "abc123",
                title: "feat: add authentication",
                timestamp: Date(timeIntervalSince1970: 1_756_700_000),
                scope: .work,
                weight: .core,
                source: .git,
                repositoryPath: "/Users/example/Code/project",
                commitSHA: "abc123"
            ),
            ShippedItem.manual(
                title: "Wrote the release notes",
                timestamp: Date(timeIntervalSince1970: 1_756_600_000),
                scope: .personal,
                weight: .minor
            ),
        ],
        repositories: [
            Repository(name: "project", path: "/Users/example/Code/project", scope: .work)
        ],
        settings: VelocitySettings(targetDailyVelocity: 2.5, gitAuthorEmail: "dev@example.com")
    )
}

struct PersistenceServiceTests {
    @Test func savingThenLoadingReturnsTheSameData() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)
        let original = sampleData()

        try await service.save(original)
        let result = await service.load()

        #expect(result.error == nil)
        #expect(result.fileExisted)
        #expect(result.data.version == original.version)
        #expect(result.data.items.map(\.id) == original.items.map(\.id))
        #expect(result.data.items.map(\.weight) == original.items.map(\.weight))
        #expect(result.data.items.map(\.scope) == original.items.map(\.scope))
        #expect(result.data.items.map(\.timestamp) == original.items.map(\.timestamp))
        #expect(result.data.repositories.map(\.path) == original.repositories.map(\.path))
        #expect(result.data.settings == original.settings)
    }

    @Test func firstLaunchWithNoFileStartsEmptyAndWritesNothing() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)

        let result = await service.load()

        #expect(result.error == nil)
        #expect(result.fileExisted == false)
        #expect(result.data.items.isEmpty)
        #expect(result.data.repositories.isEmpty)
        // A first launch must not leave a file behind before there is data.
        #expect(!FileManager.default.fileExists(atPath: temp.paths.dataFile.path(percentEncoded: false)))
    }

    @Test func storedFileIsReadableJSON() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)
        try await service.save(sampleData())

        let text = try String(contentsOf: temp.paths.dataFile, encoding: .utf8)

        #expect(text.contains("\"version\""))
        #expect(text.contains("feat: add authentication"))
        // Pretty printed, not one dense line.
        #expect(text.contains("\n  "))
        // Dates round-trip as ISO 8601, not as opaque numbers.
        #expect(text.contains("T"))
    }

    @Test func corruptFileIsPreservedRatherThanOverwritten() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)
        try await service.save(sampleData())

        let garbage = "{ this is not valid json"
        try garbage.write(to: temp.paths.dataFile, atomically: true, encoding: .utf8)

        let result = await service.load()

        // The app still starts, with an empty dataset and a reported problem.
        #expect(result.data.items.isEmpty)
        guard case .unreadableData(let quarantined) = result.error else {
            Issue.record("expected unreadableData, got \(String(describing: result.error))")
            return
        }

        // The user's bytes survive, untouched, somewhere they can find them.
        let quarantinedURL = try #require(quarantined)
        let preserved = try String(contentsOf: quarantinedURL, encoding: .utf8)
        #expect(preserved == garbage)
        #expect(!FileManager.default.fileExists(atPath: temp.paths.dataFile.path(percentEncoded: false)))
    }

    @Test func loadingTakesOneBackupPerDay() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)
        try await service.save(sampleData())

        let day = Date(timeIntervalSince1970: 1_756_700_000)
        _ = await service.load(now: day)
        _ = await service.load(now: day)

        let backups = try FileManager.default.contentsOfDirectory(
            at: temp.paths.backupsDirectory, includingPropertiesForKeys: nil
        )
        #expect(backups.count == 1)
        #expect(backups.first?.lastPathComponent == temp.paths.backupFile(for: day).lastPathComponent)
    }

    @Test func exportWritesAStandaloneFile() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)
        let destination = temp.url.appending(path: "velocity-backup.json")

        try await service.export(sampleData(), to: destination)
        let reloaded = try JSONStore().decode(VelocityData.self, from: destination)

        #expect(reloaded.items.count == 2)
    }
}

@MainActor
struct StorePersistenceTests {
    @Test func changesSurviveAStoreRestart() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)

        let first = VelocityStore(persistence: service)
        await first.load()
        first.add(ShippedItem.manual(title: "Shipped the thing", scope: .work, weight: .epic))
        first.settings.targetDailyVelocity = 4.0
        first.flushPendingSave()

        // A fresh store over the same folder is what relaunching amounts to.
        let second = VelocityStore(persistence: service)
        await second.load()

        #expect(second.shippedItems.map(\.title) == ["Shipped the thing"])
        #expect(second.settings.targetDailyVelocity == 4.0)
    }

    @Test func deletionSurvivesAStoreRestart() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)

        let first = VelocityStore(persistence: service)
        await first.load()
        first.add(contentsOf: [
            ShippedItem.manual(title: "Keep", scope: .work, weight: .core),
            ShippedItem(id: "delete-me", title: "Drop", timestamp: .now, scope: .work, weight: .core, source: .manual),
        ])
        first.delete(id: "delete-me")
        first.flushPendingSave()

        let second = VelocityStore(persistence: service)
        await second.load()

        #expect(second.shippedItems.map(\.title) == ["Keep"])
    }

    @Test func exportingWritesTheCurrentSnapshotToTheChosenFile() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)
        let store = VelocityStore(persistence: service)
        await store.load()
        store.add(ShippedItem.manual(title: "Shipped the thing", scope: .work, weight: .epic))

        let destination = temp.url.appending(path: "export.json")
        try await store.export(to: destination)

        let exported = try JSONStore().decode(VelocityData.self, from: destination)
        #expect(exported.items.map(\.title) == ["Shipped the thing"])
    }

    @Test func exportingWithoutAPersistenceLayerThrows() async {
        let store = VelocityStore()
        await #expect(throws: PersistenceError.self) {
            try await store.export(to: URL(fileURLWithPath: "/tmp/velocity-export.json"))
        }
    }

    @Test func nothingIsWrittenBeforeTheLoadCompletes() async throws {
        let temp = try TempDirectory()
        let service = PersistenceService(paths: temp.paths)
        try await service.save(sampleData())

        // A store that has not loaded yet must not overwrite the stored file
        // with its empty starting state.
        let store = VelocityStore(persistence: service)
        store.add(ShippedItem.manual(title: "Too early", scope: .work, weight: .core))
        store.flushPendingSave()

        let onDisk = await service.load()
        #expect(onDisk.data.items.count == 2)
        #expect(!onDisk.data.items.contains { $0.title == "Too early" })
    }
}
