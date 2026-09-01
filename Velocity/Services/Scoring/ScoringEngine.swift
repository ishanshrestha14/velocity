import Foundation

/// Turns a commit message into an impact weight.
///
/// Deterministic and free of SwiftUI, persistence, and Git, so the rules can be
/// read, tested, and argued about on their own.
///
/// Classification runs strongest first — breaking, then epic, then core, then
/// minor — and matching is done on the parsed conventional-commit type rather
/// than on substrings, so `fixture:` is not a `fix:` and `deployment:` is not a
/// `deploy:`.
struct ScoringEngine: Sendable {
    /// Types that represent a launch. A `!` on any type outranks this list.
    static let epicTypes: Set<String> = ["breaking", "deploy"]
    /// Types that move the product forward.
    static let coreTypes: Set<String> = ["feat", "refactor", "db"]
    /// Types that keep it tidy.
    static let minorTypes: Set<String> = ["fix", "docs", "style", "chore", "cleanup"]

    /// Words that count even without conventional-commit punctuation, because
    /// people write "cleanup old migrations" and mean it.
    static let minorKeywords: Set<String> = ["cleanup"]

    /// Anything unrecognised. Work that shipped still counts, but a message
    /// that says nothing about its impact does not get to claim a large one.
    static let fallback: ImpactWeight = .minor

    init() {}

    func score(message: String) -> ImpactWeight {
        let subject = Self.subject(of: message)
        guard !subject.isEmpty else { return Self.fallback }

        if let header = Self.parseHeader(subject) {
            // A breaking change is a launch whatever its type says.
            if header.isBreaking { return .epic }
            if Self.epicTypes.contains(header.type) { return .epic }
            if Self.coreTypes.contains(header.type) { return .core }
            if Self.minorTypes.contains(header.type) { return .minor }
            return Self.fallback
        }

        if let word = Self.firstWord(of: subject), Self.minorKeywords.contains(word) {
            return .minor
        }

        return Self.fallback
    }

    /// Score a discovered commit and turn it into a feed item, keeping the SHA
    /// as its identity and the scope of the repository it came from.
    func shippedItem(for discovered: DiscoveredCommit) -> ShippedItem {
        ShippedItem.fromCommit(
            discovered.commit,
            scope: discovered.scope,
            weight: score(message: discovered.commit.message)
        )
    }

    // MARK: - Parsing

    /// The header of a conventional commit: `type(scope)!: description`.
    struct Header: Equatable, Sendable {
        let type: String
        let isBreaking: Bool
    }

    private static func subject(of message: String) -> String {
        let firstLine = message.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? message
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstWord(of subject: String) -> String? {
        subject
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .first
            .map(String.init)
    }

    /// Parse `type(scope)!:` from the front of a subject line.
    ///
    /// Hand-written rather than a regular expression: the grammar is four
    /// tokens long, and this way a malformed header simply fails to parse
    /// instead of matching something unintended.
    static func parseHeader(_ subject: String) -> Header? {
        var index = subject.startIndex

        // type — letters, digits, and hyphens only
        var type = ""
        while index < subject.endIndex {
            let character = subject[index]
            guard character.isLetter || character.isNumber || character == "-" else { break }
            type.append(character)
            index = subject.index(after: index)
        }
        guard !type.isEmpty else { return nil }

        // optional (scope) — its contents never affect the score
        if index < subject.endIndex, subject[index] == "(" {
            guard let close = subject[index...].firstIndex(of: ")") else { return nil }
            index = subject.index(after: close)
        }

        // optional breaking marker
        var isBreaking = false
        if index < subject.endIndex, subject[index] == "!" {
            isBreaking = true
            index = subject.index(after: index)
        }

        // the colon is what makes this a header rather than an ordinary sentence
        guard index < subject.endIndex, subject[index] == ":" else { return nil }

        return Header(type: type.lowercased(), isBreaking: isBreaking)
    }
}
