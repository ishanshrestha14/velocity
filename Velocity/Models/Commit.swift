import Foundation

/// A raw Git commit as read from a repository, before scoring.
///
/// The Git SHA is the identity: a commit becomes exactly one `ShippedItem`,
/// no matter how many times the repository is scanned.
struct Commit: Codable, Identifiable, Hashable, Sendable {
    /// The full Git SHA.
    let id: String
    let message: String
    let timestamp: Date
    let repositoryPath: String
    let authorEmail: String

    var sha: String { id }

    /// The first line of the commit message, which is what the feed displays.
    var subject: String {
        message.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? message
    }
}
