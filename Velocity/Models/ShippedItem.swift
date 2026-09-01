import Foundation

/// One unit of shipped work. Git-derived and manually logged entries share this
/// model so every derived statistic has a single input type.
struct ShippedItem: Codable, Identifiable, Hashable, Sendable {
    /// Git SHA for `.git` items, a UUID string for `.manual` items.
    let id: String
    var title: String
    var timestamp: Date
    var scope: ProjectScope
    var weight: ImpactWeight
    var source: Source
    var repositoryPath: String?
    var commitSHA: String?

    enum Source: String, Codable, Sendable {
        case git
        case manual
    }

    var points: Int { weight.points }

    init(
        id: String,
        title: String,
        timestamp: Date,
        scope: ProjectScope,
        weight: ImpactWeight,
        source: Source,
        repositoryPath: String? = nil,
        commitSHA: String? = nil
    ) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.scope = scope
        self.weight = weight
        self.source = source
        self.repositoryPath = repositoryPath
        self.commitSHA = commitSHA
    }

    /// A manually logged shipment.
    static func manual(
        title: String,
        timestamp: Date = .now,
        scope: ProjectScope,
        weight: ImpactWeight
    ) -> ShippedItem {
        ShippedItem(
            id: UUID().uuidString,
            title: title,
            timestamp: timestamp,
            scope: scope,
            weight: weight,
            source: .manual
        )
    }

    /// A shipment derived from a Git commit. The SHA carries through as the id
    /// so repeated scans deduplicate naturally.
    static func fromCommit(_ commit: Commit, scope: ProjectScope, weight: ImpactWeight) -> ShippedItem {
        ShippedItem(
            id: commit.sha,
            title: commit.subject,
            timestamp: commit.timestamp,
            scope: scope,
            weight: weight,
            source: .git,
            repositoryPath: commit.repositoryPath,
            commitSHA: commit.sha
        )
    }
}
