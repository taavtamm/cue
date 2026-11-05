import CoreGraphics
import CueRender
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encoding pictures, and reading the bytes behind a slide's <img>.
enum ImageData {
    static func jpeg(_ image: CGImage, quality: Double = 0.88) -> Data? {
        encode(image, as: .jpeg, options: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    static func png(_ image: CGImage) -> Data? { encode(image, as: .png, options: [:]) }

    private static func encode(_ image: CGImage, as type: UTType, options: [CFString: Any]) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The image's bytes and a PowerPoint-friendly extension: `data:` URIs and
    /// files in the deck's folder. Other formats (WebP, HEIC) become PNG; SVG
    /// and anything unreadable return nil and stay in the background picture.
    static func bytes(for source: String, folder: DeckFolder) -> (data: Data, fileExtension: String)? {
        let raw: Data?
        if source.hasPrefix("data:") {
            raw = decodeDataURI(source)
        } else if let url = URL(string: source), url.scheme == "cue-deck",
                  case .success(let file) = folder.resolve(urlPath: url.path) {
            raw = try? Data(contentsOf: file)
        } else {
            raw = nil
        }
        guard let raw, let image = CGImageSourceCreateWithData(raw as CFData, nil),
              let type = CGImageSourceGetType(image).map({ $0 as String }) else { return nil }
        switch type {
        case UTType.png.identifier: return (raw, "png")
        case UTType.jpeg.identifier: return (raw, "jpeg")
        case UTType.gif.identifier: return (raw, "gif")
        default:
            guard let frame = CGImageSourceCreateImageAtIndex(image, 0, nil), let png = png(frame) else { return nil }
            return (png, "png")
        }
    }

    static func decodeDataURI(_ uri: String) -> Data? {
        guard let comma = uri.firstIndex(of: ",") else { return nil }
        let header = uri[..<comma], body = String(uri[uri.index(after: comma)...])
        if header.hasSuffix(";base64") { return Data(base64Encoded: body, options: .ignoreUnknownCharacters) }
        return body.removingPercentEncoding.map { Data($0.utf8) }
    }

    /// Where a picture sits and what of it shows, for CSS object-fit.
    static func placement(_ image: ExportLayout.Image)
        -> (box: CGRect, crop: PictureCrop?) {
        let box = image.box.rect
        guard image.naturalWidth > 0, image.naturalHeight > 0, box.width > 0, box.height > 0 else { return (box, nil) }
        let imageAspect = image.naturalWidth / image.naturalHeight, boxAspect = box.width / box.height
        switch image.fit {
        case "cover":
            if imageAspect > boxAspect { // Wider: cut the sides.
                let cut = (1 - boxAspect / imageAspect) / 2
                return (box, PictureCrop(left: cut, top: 0, right: cut, bottom: 0))
            }
            let cut = (1 - imageAspect / boxAspect) / 2
            return (box, PictureCrop(left: 0, top: cut, right: 0, bottom: cut))
        case "contain", "scale-down":
            if imageAspect > boxAspect {
                let height = box.width / imageAspect
                return (CGRect(x: box.minX, y: box.midY - height / 2, width: box.width, height: height), nil)
            }
            let width = box.height * imageAspect
            return (CGRect(x: box.midX - width / 2, y: box.minY, width: width, height: box.height), nil)
        default:
            return (box, nil)
        }
    }
}
