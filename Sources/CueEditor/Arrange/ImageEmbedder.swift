import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns an image file or pasted image into a `data:` URI for the deck: the
/// user chose to keep decks as one portable HTML file. Images larger than
/// twice the canvas are scaled down first, so the file stays reasonable.
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

    public func embed(_ data: Data) throws -> Embedded {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { throw ImageEmbedError.unreadable }
        let size = CGSize(width: image.width, height: image.height)
        let scale = min(1, maxPixels.width / size.width, maxPixels.height / size.height)
        let type = (CGImageSourceGetType(source) as String?).flatMap { UTType($0) }
        // Small enough, and a format browsers show: embed the original bytes.
        if scale >= 1, let type, let mime = Self.webMIME(type) {
            return Embedded(dataURI: "data:\(mime);base64," + data.base64EncodedString(), pixelSize: size, note: nil)
        }
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let resized = scale < 1 ? try Self.resize(image, to: target) : image
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        let (bytes, mime) = try Self.encode(resized, asPNG: hasAlpha)
        let note = scale < 1 ? "Scaled from \(Int(size.width)) × \(Int(size.height)) to fit the slide" : nil
        return Embedded(dataURI: "data:\(mime);base64," + bytes.base64EncodedString(), pixelSize: target, note: note)
    }

    static func webMIME(_ type: UTType) -> String? {
        if type.conforms(to: .png) { return "image/png" }
        if type.conforms(to: .jpeg) { return "image/jpeg" }
        if type.conforms(to: .gif) { return "image/gif" }
        if type.conforms(to: .webP) { return "image/webp" }
        if type.conforms(to: .svg) { return "image/svg+xml" }
        return nil
    }

    static func resize(_ image: CGImage, to size: CGSize) throws -> CGImage {
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw ImageEmbedError.unreadable }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        guard let result = context.makeImage() else { throw ImageEmbedError.unreadable }
        return result
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
