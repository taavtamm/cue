import Foundation

/// What the user allowed or refused for one deck: network hosts and device
/// permissions. Kept in `DeckGrantStore`, never beside the deck, so a deck
/// can't ship its own allowances.
public struct DeckGrants: Sendable, Equatable, Codable {
    /// Hosts this deck may load from over HTTPS, e.g. "fonts.gstatic.com". Empty = offline.
    public var allowedHosts: [String] = []
    /// Hosts the user said no to, so Cue doesn't ask again.
    public var deniedHosts: [String] = []
    /// Camera, microphone and location for this deck. All off by default.
    public var permissions = DeckPermissions.none

    public init(allowedHosts: [String] = [], deniedHosts: [String] = [], permissions: DeckPermissions = .none) {
        self.allowedHosts = allowedHosts
        self.deniedHosts = deniedHosts
        self.permissions = permissions
    }

    public static let none = DeckGrants()

    /// Nothing allowed or refused: the deck is offline and Cue will ask.
    public var isEmpty: Bool { self == .none }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowedHosts = try container.decodeIfPresent([String].self, forKey: .allowedHosts) ?? []
        deniedHosts = try container.decodeIfPresent([String].self, forKey: .deniedHosts) ?? []
        permissions = try container.decodeIfPresent(DeckPermissions.self, forKey: .permissions) ?? .none
    }
}
