import Foundation

/// Reads and writes `Codable` values as JSON files.
///
/// Deliberately knows nothing about Velocity's schema or file layout — it is the
/// encoding and safe-write mechanism, nothing more.
struct JSONStore: Sendable {
    /// Pretty-printed with sorted keys so the file stays diffable and readable
    /// by hand, which is the point of storing plain JSON.
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try Self.makeDecoder().decode(type, from: data)
    }

    /// Writes atomically: the bytes land in a temporary file that replaces the
    /// original in one step, so being killed mid-write cannot truncate the
    /// existing data.
    func encode<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try Self.makeEncoder().encode(value)
        try data.write(to: url, options: [.atomic])
    }
}
