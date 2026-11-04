import Foundation

/// Cue-specific settings stored beside a deck as `deck.cue.json`, never
/// inside the HTML (unless the user turns on "embed Cue settings").
///
/// Every field is optional on disk, so older or hand-edited files still load.
public struct CueSidecar: Sendable, Equatable, Codable {
    public static let currentVersion = 1

    public var version = CueSidecar.currentVersion
    /// Hosts this deck may load from, e.g. "fonts.gstatic.com". Empty = offline.
    public var allowedHosts: [String] = []
    /// Hosts the user said no to, so Cue doesn't ask again.
    public var deniedHosts: [String] = []
    /// Camera, microphone and location for this deck. All off by default.
    public var permissions = DeckPermissions.none
    /// Display roles keyed by a fingerprint of the connected display set.
    public var displayRoles: [String: [String: String]] = [:]
    /// Rehearsal time per slide id, in seconds.
    public var rehearsalTimings: [String: Double] = [:]
    /// How long the talk should take, in seconds. Nil = estimate from slides.
    public var targetDuration: Double?

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        allowedHosts = try container.decodeIfPresent([String].self, forKey: .allowedHosts) ?? []
        deniedHosts = try container.decodeIfPresent([String].self, forKey: .deniedHosts) ?? []
        permissions = try container.decodeIfPresent(DeckPermissions.self, forKey: .permissions) ?? .none
        displayRoles = try container.decodeIfPresent([String: [String: String]].self, forKey: .displayRoles) ?? [:]
        rehearsalTimings = try container.decodeIfPresent([String: Double].self, forKey: .rehearsalTimings) ?? [:]
        targetDuration = try container.decodeIfPresent(Double.self, forKey: .targetDuration)
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
