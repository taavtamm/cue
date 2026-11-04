import CueCore
import Foundation
import ImageIO

/// Without Keynote, a .key file can only show the picture of its first
/// slide that Keynote stores inside it (`preview.jpg`). Present-only.
struct KeynotePreviewImporter: DeckImporter {
    func makeDeck(from url: URL, assets: AssetStore, report: inout ImportReport) async throws -> ImportedDeck {
        let data: Data
        if let zip = try? ZipArchive(contentsOf: url), let preview = try? zip.data(for: "preview.jpg") {
            data = preview
        } else if let preview = try? Data(contentsOf: url.appendingPathComponent("preview.jpg")) {
            data = preview // Older package-folder .key files.
        } else {
            throw ImportError.needsKeynote("key")
        }
        let size = ImageSize.of(data) ?? CGSize(width: 1920, height: 1080)
        let source = assets.add(data, key: "preview.jpg", preferredName: "preview.jpg")
        let frame = Rect(x: 0, y: 0, width: size.width, height: size.height)
        var deck = ImportedDeck(title: url.deletingPathExtension().lastPathComponent,
                                canvas: CanvasSize(width: size.width, height: size.height))
        deck.slides = [ImportedSlide(label: "Slide 1", elements: [
            ImportedElement(name: "Keynote preview", frame: frame, content: .image(source: source, crop: nil, alt: "Slide 1")),
        ])]
        deck.isPresentOnly = true
        report.note("Without Keynote, only a picture of the first slide is available. Install Keynote to open every slide.")
        return deck
    }
}

enum ImageSize {
    static func of(_ data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double else { return nil }
        return CGSize(width: width, height: height)
    }
}
