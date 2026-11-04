import Foundation

/// What a deck may ask the Mac for beyond showing itself. Everything is off
/// unless the user turned it on for this deck; a deck can't turn it on.
public struct DeckPermissions: Sendable, Equatable, Codable {
    public var camera = false
    public var microphone = false
    public var location = false

    public init(camera: Bool = false, microphone: Bool = false, location: Bool = false) {
        self.camera = camera
        self.microphone = microphone
        self.location = location
    }

    public static let none = DeckPermissions()

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        camera = try container.decodeIfPresent(Bool.self, forKey: .camera) ?? false
        microphone = try container.decodeIfPresent(Bool.self, forKey: .microphone) ?? false
        location = try container.decodeIfPresent(Bool.self, forKey: .location) ?? false
    }
}
