import Foundation

/// A commit found by a scan, paired with the scope of the repository it came
/// from. Scoring turns these into `ShippedItem`s.
struct DiscoveredCommit: Identifiable, Hashable, Sendable {
    let commit: Commit
    let scope: ProjectScope

    var id: String { commit.id }
}

/// What one repository produced during a scan.
struct RepositoryScanResult: Identifiable, Sendable {
    let repositoryID: Repository.ID
    let repositoryName: String
    let repositoryPath: String
    /// Commits in the log authored by the configured author.
    let matchingCommits: Int
    /// Of those, the ones not already imported.
    let newCommits: [DiscoveredCommit]
    /// Set when this repository could not be read. Other repositories still ran.
    let error: GitError?

    var id: Repository.ID { repositoryID }
    var succeeded: Bool { error == nil }
}

/// The outcome of scanning every enabled repository.
struct ScanReport: Sendable {
    let startedAt: Date
    let finishedAt: Date
    let results: [RepositoryScanResult]

    var newCommits: [DiscoveredCommit] {
        results.flatMap(\.newCommits)
    }

    var failedRepositories: [RepositoryScanResult] {
        results.filter { !$0.succeeded }
    }

    var scannedRepositoryCount: Int {
        results.filter(\.succeeded).count
    }

    var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }

    static func empty(at date: Date = .now) -> ScanReport {
        ScanReport(startedAt: date, finishedAt: date, results: [])
    }
}
