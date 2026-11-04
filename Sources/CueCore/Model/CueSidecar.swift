import Foundation

/// Cue-specific settings stored beside a deck as `deck.cue.json`, never
/// inside the HTML (unless the user turns on "embed Cue settings").
public struct CueSidecar: Sendable, Equatable, Codable {
    public static let currentVersion = 1

    public var version = CueSidecar.currentVersion
    /// Hosts this deck may load from, e.g. "fonts.gstatic.com". Empty = offline.
    public var allowedHosts: [String] = []
    /// Hosts the user said no to, so Cue doesn't ask again.
    public var deniedHosts: [String] = []
    /// Display roles keyed by a fingerprint of the connected display set.
    public var displayRoles: [String: [String: String]] = [:]
    /// Rehearsal time per slide id, in seconds.
    public var rehearsalTimings: [String: Double] = [:]

    public init() {}

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
