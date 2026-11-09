import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns an image file or pasted image into a `data:` URI for the deck: the
/// deck stays one portable HTML file, with no folder of assets beside it.
/// Images larger than twice the canvas are scaled down first, so the file
/// stays reasonable.
public struct ImageEmbedder: Sendable {
    public struct Embedded: Sendable, Equatable {
        public let dataURI: String
        /// Pixel size of the embedded image.
        public let pixelSize: CGSize
        /// Set when the image was scaled down, e.g. "Scaled from 8000 × 6000".
        public let note: String?
    }

    public let canvas: CGSize

    public init(canvas: CGSize) {
        self.canvas = canvas
    }

    public var maxPixels: CGSize { CGSize(width: canvas.width * 2, height: canvas.height * 2) }

    public func embed(contentsOf url: URL) throws -> Embedded {
        try embed(Data(contentsOf: url))
    }

    /// Sizes are as displayed: EXIF orientation (a phone photo taken upright)
    /// is applied, both to the reported size and to any re-encoded pixels.
    public func embed(_ data: Data) throws -> Embedded {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let info = Self.orientedInfo(source)
        else { throw ImageEmbedError.unreadable }
        let size = info.size
        let scale = min(1, maxPixels.width / size.width, maxPixels.height / size.height)
        let type = (CGImageSourceGetType(source) as String?).flatMap { UTType($0) }
        // Small enough, and a format browsers show: embed the original bytes
        // (browsers apply EXIF orientation themselves).
        if scale >= 1, let type, let mime = Self.webMIME(type) {
            return Embedded(dataURI: "data:\(mime);base64," + data.base64EncodedString(), pixelSize: size, note: nil)
        }
        let longest = max(size.width * scale, size.height * scale).rounded()
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(longest)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { throw ImageEmbedError.unreadable }
        let (bytes, mime) = try Self.encode(image, asPNG: info.hasAlpha)
        let note = scale < 1 ? "Scaled from \(Int(size.width)) × \(Int(size.height)) to fit the slide" : nil
        let pixelSize = CGSize(width: image.width, height: image.height)
        return Embedded(dataURI: "data:\(mime);base64," + bytes.base64EncodedString(), pixelSize: pixelSize, note: note)
    }

    /// The first image's displayed size (width and height swap for the
    /// rotated EXIF orientations 5–8) and whether it has alpha.
    static func orientedInfo(_ source: CGImageSource) -> (size: CGSize, hasAlpha: Bool)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width > 0, height > 0
        else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let rotated = (5...8).contains(orientation)
        let size = rotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
        return (size, properties[kCGImagePropertyHasAlpha] as? Bool ?? false)
    }

    static func webMIME(_ type: UTType) -> String? {
        if type.conforms(to: .png) { return "image/png" }
        if type.conforms(to: .jpeg) { return "image/jpeg" }
        if type.conforms(to: .gif) { return "image/gif" }
        if type.conforms(to: .webP) { return "image/webp" }
        if type.conforms(to: .svg) { return "image/svg+xml" }
        return nil
    }

    static func encode(_ image: CGImage, asPNG: Bool) throws -> (Data, String) {
        let data = NSMutableData()
        let type = asPNG ? UTType.png : UTType.jpeg
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)
        else { throw ImageEmbedError.unreadable }
        let options = asPNG ? nil : [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { throw ImageEmbedError.unreadable }
        return (data as Data, asPNG ? "image/png" : "image/jpeg")
    }
}

public enum ImageEmbedError: Error, Sendable {
    case unreadable
}
