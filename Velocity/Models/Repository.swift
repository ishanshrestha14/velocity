import Foundation

/// A local Git repository the user has asked Velocity to watch.
struct Repository: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    /// Absolute path on disk. Velocity never guesses or globs for repositories.
    var path: String
    var scope: ProjectScope
    var enabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        scope: ProjectScope,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.scope = scope
        self.enabled = enabled
    }

    var url: URL { URL(fileURLWithPath: path) }
}
