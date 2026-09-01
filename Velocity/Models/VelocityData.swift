import Foundation

/// The on-disk document. Versioned from day one so later schema changes can be
/// migrated rather than guessed at.
struct VelocityData: Codable, Sendable {
    static let currentVersion = 1

    var version: Int
    var items: [ShippedItem]
    var repositories: [Repository]
    var settings: VelocitySettings

    init(
        version: Int = VelocityData.currentVersion,
        items: [ShippedItem] = [],
        repositories: [Repository] = [],
        settings: VelocitySettings = .default
    ) {
        self.version = version
        self.items = items
        self.repositories = repositories
        self.settings = settings
    }

    static let empty = VelocityData()
}
