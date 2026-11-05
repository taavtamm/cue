import CoreGraphics
import CueRender
import Foundation

/// One slide ready to write: its editable parts, the picture of everything
/// else, and its speaker notes.
public struct ExportedSlide: Sendable {
    public var layout: ExportLayout
    /// The slide without its text boxes and pictures (JPEG): shapes,
    /// gradients, SVG, canvas and live embeds, frozen.
    public var background: Data
    public var pictures: [ExportedPicture]
    public var notes: String

    public init(layout: ExportLayout, background: Data, pictures: [ExportedPicture], notes: String) {
        self.layout = layout
        self.background = background
        self.pictures = pictures
        self.notes = notes
    }
}

/// A picture placed on a slide, with its own image bytes.
public struct ExportedPicture: Sendable {
    /// In canvas pixels.
    public var box: CGRect
    public var data: Data
    /// png, jpeg or gif.
    public var fileExtension: String
    /// What's cut from each side (CSS object-fit: cover).
    public var crop: PictureCrop?
    public var opacity: Double

    public init(box: CGRect, data: Data, fileExtension: String,
                crop: PictureCrop? = nil, opacity: Double = 1) {
        self.box = box
        self.data = data
        self.fileExtension = fileExtension
        self.crop = crop
        self.opacity = opacity
    }
}

/// Fractions of a picture cut from each side, 0…1.
public struct PictureCrop: Sendable, Equatable {
    public var left, top, right, bottom: Double
    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }
}

/// Canvas pixels → PowerPoint units. Slides are 13.333 in wide like a
/// standard 16:9 PowerPoint slide, whatever the deck's canvas size, so text
/// sizes look as they would in a deck made in PowerPoint.
public struct PptxScale: Sendable, Equatable {
    public static let slideWidth = 12_192_000.0

    public let emuPerPixel: Double
    public let pointsPerPixel: Double

    public init(canvasWidth: Double) {
        emuPerPixel = Self.slideWidth / max(1, canvasWidth)
        pointsPerPixel = emuPerPixel / 12_700 // 12 700 EMU per point.
    }

    public func emu(_ pixels: Double) -> Int { Int((pixels * emuPerPixel).rounded()) }
    /// Hundredths of a point, as DrawingML sizes are written.
    public func centipoints(_ pixels: Double) -> Int { Int((pixels * pointsPerPixel * 100).rounded()) }
}
