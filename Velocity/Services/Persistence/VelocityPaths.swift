import Foundation

/// Where Velocity keeps its data on disk.
///
/// Everything lives under Application Support. Nothing is ever written into the
/// project directory, and nothing leaves the machine.
struct VelocityPaths: Sendable {
    let root: URL

    static let applicationSupportDirectoryName = "Velocity"
    static let dataFileName = "velocity.json"
    static let backupsDirectoryName = "backups"

    init(root: URL) {
        self.root = root
    }

    /// `~/Library/Application Support/Velocity/`
    static func `default`(fileManager: FileManager = .default) throws -> VelocityPaths {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return VelocityPaths(root: applicationSupport.appending(path: applicationSupportDirectoryName))
    }

    var dataFile: URL { root.appending(path: Self.dataFileName) }
    var backupsDirectory: URL { root.appending(path: Self.backupsDirectoryName) }

    /// The daily snapshot taken from the last known-good file.
    func backupFile(for date: Date, calendar: Calendar = .current) -> URL {
        backupsDirectory.appending(path: "velocity-\(Self.dayStamp(date, calendar: calendar)).json")
    }

    /// Where an unreadable file gets moved so it is never overwritten.
    func quarantineFile(for date: Date) -> URL {
        backupsDirectory.appending(path: "velocity-unreadable-\(Self.timestamp(date)).json")
    }

    private static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func timestamp(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        return String(
            format: "%04d-%02d-%02d-%02d%02d%02d",
            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0,
            parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0
        )
    }
}
