import Foundation

/// Everything the Git layer can fail with.
///
/// A repository that has been moved, renamed, or is on an unmounted disk is an
/// ordinary condition, not an exceptional one — none of these should ever reach
/// the user as a crash.
enum GitError: LocalizedError, Equatable, Sendable {
    case executableUnavailable(String)
    case repositoryNotFound(path: String)
    case pathIsNotADirectory(path: String)
    case notARepository(path: String)
    case permissionDenied(path: String)
    case commandFailed(status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            "Git is unavailable."
        case .repositoryNotFound:
            "Repository not found."
        case .pathIsNotADirectory:
            "That path is not a folder."
        case .notARepository:
            "This folder is not a Git repository."
        case .permissionDenied:
            "Permission denied."
        case .commandFailed:
            "Git command failed."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .executableUnavailable(let detail):
            "Install the Xcode Command Line Tools with `xcode-select --install`. (\(detail))"
        case .repositoryNotFound(let path):
            "Nothing exists at \(path). It may have been moved, renamed, or be on a disk that is not mounted."
        case .pathIsNotADirectory(let path):
            "\(path) is a file. Choose the repository's folder instead."
        case .notARepository(let path):
            "\(path) has no .git directory. Choose the top level of a repository."
        case .permissionDenied(let path):
            "macOS may need permission to read \(path). Choosing the folder again in Settings usually grants it."
        case .commandFailed(let status, let message):
            message.isEmpty ? "git exited with status \(status)." : message
        }
    }

    /// The short form shown next to a repository row.
    var shortDescription: String {
        errorDescription ?? "Git error."
    }
}
