import OSLog

/// Loggers for the parts of the app that do work the user cannot see.
///
/// A scan runs in the background against folders that may have moved or been
/// deleted; when it comes back with nothing, the log is the only way to tell
/// "no new commits" from "the repository could not be read".
enum AppLog {
    static let subsystem = "dev.local.Velocity"

    static let scan = Logger(subsystem: subsystem, category: "scan")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
