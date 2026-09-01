import Foundation

/// Runs `git` as a subprocess.
///
/// Arguments go to `Process` as an array and never through a shell, so a path
/// or an email containing a space, quote, or semicolon is data rather than
/// syntax. There is no `sh -c` anywhere in this type on purpose.
struct GitRunner: Sendable {
    let executableURL: URL

    /// Where git usually lives. `/usr/bin/git` is the system shim and is tried
    /// first; Homebrew locations cover machines where it is not installed.
    static let candidatePaths = [
        "/usr/bin/git",
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git",
    ]

    init(executableURL: URL) {
        self.executableURL = executableURL
    }

    static func locate(fileManager: FileManager = .default) throws -> GitRunner {
        for path in candidatePaths where fileManager.isExecutableFile(atPath: path) {
            return GitRunner(executableURL: URL(fileURLWithPath: path))
        }
        throw GitError.executableUnavailable("git was not found in \(candidatePaths.joined(separator: ", "))")
    }

    struct Output: Sendable {
        let standardOutput: String
        let standardError: String
        let terminationStatus: Int32

        var succeeded: Bool { terminationStatus == 0 }
    }

    /// Run git and collect its output. Never throws on a non-zero exit — that is
    /// information the caller usually wants to inspect rather than a failure.
    ///
    /// The subprocess is driven on a Dispatch queue rather than on Swift
    /// Concurrency's cooperative pool. Waiting on a process blocks its thread,
    /// and the cooperative pool has roughly one thread per core: a handful of
    /// concurrent repository scans would consume all of them and deadlock every
    /// other task in the process, this app's UI included.
    func run(_ arguments: [String], in directory: URL? = nil) async throws -> Output {
        let executableURL = executableURL
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let output = try Self.runBlocking(
                        executableURL: executableURL,
                        arguments: arguments,
                        directory: directory
                    )
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Holds bytes read on one queue for collection on another. The
    /// `DispatchGroup` provides the ordering that makes the handoff safe.
    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }

    private static func runBlocking(
        executableURL: URL,
        arguments: [String],
        directory: URL?
    ) throws -> Output {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice

        // Keep git non-interactive: a repository needing credentials must fail
        // rather than block the scan on a prompt that has no UI to appear in.
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_PAGER"] = "cat"
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw GitError.executableUnavailable(error.localizedDescription)
        }

        // Both pipes are drained concurrently. Reading one to completion first
        // deadlocks as soon as the other fills its 64KB buffer — which a long
        // git log reliably does.
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading
        let outputBox = DataBox()
        let errorBox = DataBox()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        queue.async(group: group) {
            outputBox.data = (try? outputHandle.readToEnd()) ?? Data()
        }
        queue.async(group: group) {
            errorBox.data = (try? errorHandle.readToEnd()) ?? Data()
        }
        group.wait()
        process.waitUntilExit()

        return Output(
            standardOutput: String(decoding: outputBox.data, as: UTF8.self),
            standardError: String(decoding: errorBox.data, as: UTF8.self),
            terminationStatus: process.terminationStatus
        )
    }

    /// Run git and return stdout, turning a non-zero exit into a `GitError`.
    func runExpectingSuccess(_ arguments: [String], in directory: URL? = nil) async throws -> String {
        let output = try await run(arguments, in: directory)
        guard output.succeeded else {
            throw GitError.commandFailed(
                status: output.terminationStatus,
                message: output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return output.standardOutput
    }

    /// The machine's configured Git identity, for the "Detect" button in
    /// Settings. Returns nil when git has no global user.email set.
    func detectGlobalAuthorEmail() async -> String? {
        guard let output = try? await run(["config", "--global", "--get", "user.email"]),
              output.succeeded
        else { return nil }
        let email = output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.isEmpty ? nil : email
    }
}
