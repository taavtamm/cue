import Foundation

/// Cue-specific settings stored beside a deck as `deck.cue.json`, never
/// inside the HTML (unless the user turns on "embed Cue settings").
///
/// Every field is optional on disk, so older or hand-edited files still load.
///
/// Nothing here grants anything. Anyone can ship a sidecar with a deck, so
/// allowed hosts and device permissions live in `DeckGrantStore` instead, and
/// the `allowedHosts`, `deniedHosts` and `permissions` keys older versions
/// wrote here are ignored.
public struct CueSidecar: Sendable, Equatable, Codable {
    public static let currentVersion = 1

    public var version = CueSidecar.currentVersion
    /// Display roles keyed by a fingerprint of the connected display set.
    public var displayRoles: [String: [String: String]] = [:]
    /// Rehearsal time per slide id, in seconds.
    public var rehearsalTimings: [String: Double] = [:]
    /// How long the talk should take, in seconds. Nil = estimate from slides.
    public var targetDuration: Double?
    /// The user chose Never on the heavy-deck warning for this deck.
    public var hidesPerformanceWarning = false

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        displayRoles = try container.decodeIfPresent([String: [String: String]].self, forKey: .displayRoles) ?? [:]
        rehearsalTimings = try container.decodeIfPresent([String: Double].self, forKey: .rehearsalTimings) ?? [:]
        targetDuration = try container.decodeIfPresent(Double.self, forKey: .targetDuration)
        hidesPerformanceWarning = try container.decodeIfPresent(Bool.self, forKey: .hidesPerformanceWarning) ?? false
    }

    /// `deck.cue.json` next to `deck.html`.
    public static func url(forDeck deckURL: URL) -> URL {
        deckURL.deletingPathExtension().appendingPathExtension("cue.json")
    }

    public static func load(from url: URL) throws -> CueSidecar {
        guard FileManager.default.fileExists(atPath: url.path) else { return CueSidecar() }
        return try JSONDecoder().decode(CueSidecar.self, from: Data(contentsOf: url))
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
