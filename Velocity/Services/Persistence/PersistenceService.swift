import Foundation

/// Owns Velocity's on-disk state.
///
/// An actor, so file I/O never runs on the main actor and the UI stays
/// responsive while saving. It is the only type that knows where the data lives.
actor PersistenceService {
    private let paths: VelocityPaths
    private let store = JSONStore()
    // FileManager is documented as thread-safe for the file operations used
    // here, which lets the synchronous termination write reach it too.
    private nonisolated(unsafe) let fileManager: FileManager

    /// How many daily backups to keep before the oldest are pruned.
    private let backupsToKeep = 7

    init(paths: VelocityPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    init(fileManager: FileManager = .default) throws {
        self.init(paths: try VelocityPaths.default(fileManager: fileManager), fileManager: fileManager)
    }

    nonisolated var dataFileURL: URL { paths.dataFile }
    nonisolated var rootDirectoryURL: URL { paths.root }

    // MARK: - Loading

    /// The result of a load. A first launch and a damaged file both yield usable
    /// state; the caller decides what to tell the user about the difference.
    struct LoadResult: Sendable {
        var data: VelocityData
        /// Set when the stored file could not be read. The file was preserved.
        var error: PersistenceError?
        /// False on a first launch, when there is nothing to read yet.
        var fileExisted: Bool
    }

    func load(now: Date = .now) async -> LoadResult {
        do {
            try createDirectoriesIfNeeded()
        } catch {
            return LoadResult(
                data: .empty,
                error: .directoryUnavailable(error.localizedDescription),
                fileExisted: false
            )
        }

        guard fileManager.fileExists(atPath: paths.dataFile.path(percentEncoded: false)) else {
            // First launch. Start empty and write nothing until there is
            // something worth saving.
            return LoadResult(data: .empty, error: nil, fileExisted: false)
        }

        do {
            let data = try store.decode(VelocityData.self, from: paths.dataFile)
            backUpCurrentFileIfNeeded(now: now)
            return LoadResult(data: data, error: nil, fileExisted: true)
        } catch {
            // Never overwrite something we could not understand — move it aside
            // so the user still has their file.
            let quarantined = quarantineDataFile(now: now)
            return LoadResult(
                data: .empty,
                error: .unreadableData(quarantinedAt: quarantined),
                fileExisted: true
            )
        }
    }

    // MARK: - Saving

    func save(_ data: VelocityData) async throws {
        try writeSynchronously(data)
    }

    /// The same write, callable without awaiting.
    ///
    /// `applicationWillTerminate` cannot await, and a debounced save that has
    /// not fired yet would be lost. Safe to expose as `nonisolated` because it
    /// touches only immutable, sendable state and the write itself is atomic.
    nonisolated func writeSynchronously(_ data: VelocityData) throws {
        do {
            try createDirectoriesIfNeeded()
            try store.encode(data, to: paths.dataFile)
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Export

    /// Writes the current state to a standalone file the user chose.
    func export(_ data: VelocityData, to url: URL) async throws {
        do {
            try store.encode(data, to: url)
        } catch {
            throw PersistenceError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Directories and backups

    private nonisolated func createDirectoriesIfNeeded() throws {
        try fileManager.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.backupsDirectory, withIntermediateDirectories: true)
    }

    /// Keeps one snapshot per day of the last file that read cleanly.
    private func backUpCurrentFileIfNeeded(now: Date) {
        let destination = paths.backupFile(for: now)
        guard !fileManager.fileExists(atPath: destination.path(percentEncoded: false)) else { return }
        try? fileManager.copyItem(at: paths.dataFile, to: destination)
        pruneBackups()
    }

    private func pruneBackups() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: paths.backupsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        // Only daily snapshots are pruned. Quarantined files are the user's
        // damaged data and are never deleted automatically.
        let daily = contents
            .filter { $0.lastPathComponent.hasPrefix("velocity-") }
            .filter { !$0.lastPathComponent.hasPrefix("velocity-unreadable-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard daily.count > backupsToKeep else { return }
        for url in daily.prefix(daily.count - backupsToKeep) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func quarantineDataFile(now: Date) -> URL? {
        let destination = paths.quarantineFile(for: now)
        do {
            try fileManager.moveItem(at: paths.dataFile, to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
