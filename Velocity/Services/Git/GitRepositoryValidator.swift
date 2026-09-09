import Foundation

/// Checks that a path is something Velocity can actually scan, before it is
/// added and before every scan.
///
/// The filesystem checks come first because they produce a precise message —
/// "not a folder", "no .git here" — where git itself would only say "fatal".
// @unchecked rather than nonisolated(unsafe) on the property: the latter's
// support for a plain (non-actor) stored property isn't consistent across
// Swift 6 toolchain versions — it built locally but failed in CI on Xcode
// 16.4 with "Non-sendable type 'FileManager' ... cannot exit
// nonisolated(unsafe) context". @unchecked Sendable is the older, uniformly
// supported escape hatch for the same guarantee: FileManager's documented
// thread-safety on the operations used here.
struct GitRepositoryValidator: @unchecked Sendable {
    let runner: GitRunner
    let fileManager: FileManager

    init(runner: GitRunner, fileManager: FileManager = .default) {
        self.runner = runner
        self.fileManager = fileManager
    }

    /// Throws a `GitError` describing exactly what is wrong with `path`.
    func validate(path: String) async throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw GitError.repositoryNotFound(path: path)
        }
        guard isDirectory.boolValue else {
            throw GitError.pathIsNotADirectory(path: path)
        }
        guard fileManager.isReadableFile(atPath: path) else {
            throw GitError.permissionDenied(path: path)
        }

        // A worktree or submodule has .git as a file pointing elsewhere, so
        // check for presence rather than for a directory.
        let dotGit = URL(fileURLWithPath: path).appending(path: ".git")
        guard fileManager.fileExists(atPath: dotGit.path(percentEncoded: false)) else {
            throw GitError.notARepository(path: path)
        }

        // Ask git itself, which catches the cases the filesystem cannot: a
        // damaged .git, or a directory inside a repository rather than its root.
        let output = try await runner.run(
            ["rev-parse", "--is-inside-work-tree"],
            in: URL(fileURLWithPath: path)
        )
        guard output.succeeded else {
            let message = output.standardError.lowercased()
            if message.contains("permission denied") {
                throw GitError.permissionDenied(path: path)
            }
            throw GitError.notARepository(path: path)
        }
    }

    /// A default display name for a newly added repository.
    static func suggestedName(for path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return name.isEmpty ? path : name
    }
}
