import Foundation

/// Turns `git log` output into `Commit` values.
///
/// Kept free of `Process` and of Velocity's state so the parsing rules can be
/// tested against fixture text alone.
struct GitCommitParser: Sendable {
    /// Records are separated by 0x1E and fields by 0x1F — control characters
    /// that cannot occur in a commit message, unlike any printable delimiter.
    static let recordSeparator: Character = "\u{1e}"
    static let fieldSeparator: Character = "\u{1f}"

    /// SHA, author date, author email, then the full message last because it is
    /// the only field that can contain newlines.
    static let prettyFormat = "%H%x1f%aI%x1f%aE%x1f%B%x1e"

    /// The arguments that produce output this parser understands.
    ///
    /// Merges are excluded: a merge commit is bookkeeping, not shipped work,
    /// and counting it would inflate the score it is supposed to measure.
    static func logArguments() -> [String] {
        ["log", "--no-merges", "--date-order", "--pretty=format:\(prettyFormat)"]
    }

    func parse(_ output: String, repositoryPath: String) -> [Commit] {
        output
            .split(separator: Self.recordSeparator, omittingEmptySubsequences: true)
            .compactMap { parseRecord($0, repositoryPath: repositoryPath) }
    }

    private func parseRecord(_ record: Substring, repositoryPath: String) -> Commit? {
        let trimmed = record.drop(while: \.isNewline)
        let fields = trimmed.split(
            separator: Self.fieldSeparator,
            maxSplits: 3,
            omittingEmptySubsequences: false
        )
        guard fields.count == 4 else { return nil }

        let sha = String(fields[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sha.isEmpty else { return nil }

        guard let timestamp = Self.date(from: String(fields[1])) else { return nil }

        let email = String(fields[2]).trimmingCharacters(in: .whitespacesAndNewlines)
        let message = String(fields[3]).trimmingCharacters(in: .whitespacesAndNewlines)

        // A commit with an empty message is still a commit; one without a SHA or
        // a readable date is not something we can identify or place in time.
        return Commit(
            id: sha,
            message: message,
            timestamp: timestamp,
            repositoryPath: repositoryPath,
            authorEmail: email
        )
    }

    // ISO8601DateFormatter is documented as thread-safe, and this one is only
    // ever read from.
    private nonisolated(unsafe) static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func date(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return isoFormatter.date(from: trimmed)
    }
}
