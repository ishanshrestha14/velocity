import Foundation

/// Classification of where a shipment belongs. Repositories carry a scope so that
/// Git-derived items can be classified automatically.
enum ProjectScope: String, Codable, CaseIterable, Sendable, Identifiable {
    case work
    case personal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .work: "Work"
        case .personal: "Personal"
        }
    }
}

/// The dashboard-level filter. Distinct from `ProjectScope` because "all" is a
/// view concern, not a property a shipped item can have.
enum ScopeFilter: String, CaseIterable, Sendable, Identifiable {
    case all
    case work
    case personal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All Projects"
        case .work: "Work"
        case .personal: "Personal"
        }
    }

    /// The scope this filter narrows to, or `nil` when it admits everything.
    var scope: ProjectScope? {
        switch self {
        case .all: nil
        case .work: .work
        case .personal: .personal
        }
    }

    func matches(_ scope: ProjectScope) -> Bool {
        self.scope == nil || self.scope == scope
    }
}
