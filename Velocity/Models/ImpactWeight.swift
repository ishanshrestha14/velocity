import Foundation

/// The 1 / 3 / 5 impact system. The raw value *is* the point value, so scoring
/// arithmetic never needs a lookup table.
enum ImpactWeight: Int, Codable, CaseIterable, Sendable, Identifiable {
    case minor = 1
    case core = 3
    case epic = 5

    var id: Int { rawValue }

    var points: Int { rawValue }

    var displayName: String {
        switch self {
        case .minor: "Minor Tweak"
        case .core: "Core Feature"
        case .epic: "Epic Launch"
        }
    }

    var shortLabel: String { "\(rawValue)" }
}
