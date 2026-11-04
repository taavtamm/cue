import Foundation

/// Where the show is. Broadcast from ShowController to every surface.
public struct ShowPosition: Sendable, Equatable, Codable, Hashable {
    public var slide: Int
    public var build: Int
    public init(slide: Int, build: Int = 0) {
        self.slide = slide
        self.build = build
    }
    public static let start = ShowPosition(slide: 0, build: 0)
}
