import CoreGraphics
import Foundation

/// One connected screen, described without AppKit so role logic is testable.
public struct DisplayInfo: Sendable, Equatable, Codable, Identifiable {
    /// Stable across reconnects: the display's UUID where macOS provides one.
    public var id: String
    public var name: String
    /// Frame in global screen coordinates (points, origin bottom-left).
    public var frame: CGRect
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var isBuiltIn: Bool
    /// The screen with the menu bar.
    public var isMain: Bool

    public init(
        id: String, name: String, frame: CGRect,
        pixelWidth: Int, pixelHeight: Int, isBuiltIn: Bool = false, isMain: Bool = false
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isBuiltIn = isBuiltIn
        self.isMain = isMain
    }

    public var resolutionText: String { "\(pixelWidth) × \(pixelHeight)" }
    var area: Double { Double(pixelWidth) * Double(pixelHeight) }
}

extension Array where Element == DisplayInfo {
    /// Identifies this combination of screens, so roles are remembered per room.
    public var setKey: String { map(\.id).sorted().joined(separator: "+") }
}
