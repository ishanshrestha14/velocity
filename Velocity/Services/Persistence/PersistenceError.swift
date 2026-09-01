import Foundation

/// Failures the persistence layer can report. Every case carries a message the
/// UI can show as-is, because a silent failure here means lost work.
enum PersistenceError: LocalizedError, Equatable {
    /// The stored file exists but could not be decoded. It has been moved aside,
    /// not overwritten.
    case unreadableData(quarantinedAt: URL?)
    case directoryUnavailable(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableData:
            "Unable to load Velocity data."
        case .directoryUnavailable:
            "Unable to open Velocity's data folder."
        case .writeFailed:
            "Unable to save Velocity data."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unreadableData(let quarantinedAt):
            if let quarantinedAt {
                "The unreadable file was kept at \(quarantinedAt.path(percentEncoded: false)). Velocity started with an empty dataset rather than overwriting it."
            } else {
                "Velocity started with an empty dataset rather than overwriting the existing file."
            }
        case .directoryUnavailable(let detail):
            "macOS may need to grant access to Application Support. (\(detail))"
        case .writeFailed(let detail):
            "Recent changes are still in memory and will be retried on the next change. (\(detail))"
        }
    }
}
