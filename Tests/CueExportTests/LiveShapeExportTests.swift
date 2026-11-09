import CoreGraphics
import CueCore
import CueImport
import CueRender
import Foundation
import ImageIO
import Testing
@testable import CueExport

/// The demo deck's slide 3, rendered offscreen: its four cards come out as
/// PowerPoint shapes under their text, the flat background as the slide's
/// own, and the flattened picture no longer shows the cards.
/// Set CUE_EXPORT_RENDER_DIR to keep "demo-deck-slide3.pptx" for a visual check.
@Suite("Exporting the demo deck's shapes", .serialized)
@MainActor
struct LiveShapeExportTests {
    static let cardBorder = "rgb(58, 54, 48)"

    @Test func slideThreesCardsAreShapesBehindTheirText() async throws {
        let document = try ExportFixtures.demoDeck()
        let renderer = ExportRenderer(document: document)
        defer { renderer.close() }
        try await renderer.start()
        let folder = DeckFolder(root: document.fileURL.deletingLastPathComponent())
        let slide = try await DeckExport.slide(2, renderer: renderer, folder: folder)
        let layout = slide.layout

        #expect(layout.background?.type == "solid" && layout.background?.color == "rgb(20, 18, 16)")
        let cards = layout.shapes.filter { $0.geometry == "roundRect" && $0.line?.color == Self.cardBorder }
        #expect(cards.count == 4)
        for card in cards {
            #expect(abs(card.radius - 8) < 0.01 && card.line?.width == 1 && card.fill == nil)
            let inside = layout.texts.filter { card.box.rect.contains($0.box.rect.insetBy(dx: 1, dy: 1)) }
            #expect(inside.count == 2, "a card's label and its sentence")
            #expect(inside.allSatisfy { ($0.order ?? -1) > card.order }, "the card is behind its text")
        }
        let quote = layout.shapes.first { $0.sides?[3]?.width == 4 }
        #expect(quote != nil, "the quote's left rule is a line")

        let xml = PptxSlideXML.slide(slide, scale: PptxScale(canvasWidth: layout.width))
        #expect(xml.contains(#"<p:bg><p:bgPr><a:solidFill><a:srgbClr val="141210">"#), "the background is p:bg")
        #expect(xml.components(separatedBy: #"prst="roundRect""#).count - 1 == 4)
        let firstCard = try #require(xml.range(of: #"prst="roundRect""#)).lowerBound
        let firstLabel = try #require(xml.range(of: "01 · CLEAR")).lowerBound
        #expect(firstCard < firstLabel)

        // Wherever the flattened picture reaches, it doesn't show the cards' borders.
        if let flat = slide.background {
            let picture = try #require(Self.image(flat.data))
            for card in cards {
                for point in [CGPoint(x: card.box.x + 0.5, y: card.box.y + card.box.height / 2),
                              CGPoint(x: card.box.x + card.box.width / 2, y: card.box.y + 0.5)] {
                    let pixel = Self.pixel(picture, at: point, box: flat.box)
                    #expect(pixel.map { $0.matches(red: 20, green: 18, blue: 16) } ?? true,
                            "the picture at \(point) is \(String(describing: pixel)), not the background")
                }
            }
        }

        let url = try output().appending(path: "demo-deck-slide3.pptx")
        try PptxWriter.data(slides: [slide], title: "demo-deck-slide3").write(to: url)
        let back = try DeckDocument(contentsOf: try await ImportService().prepare(url).htmlURL)
        #expect(back.structure.slides.count == 1)
        #expect(back.source.contains("01 · CLEAR") && back.source.contains("One question, answered."))
        #expect(back.source.lowercased().contains("#3a3630") || back.source.contains("58, 54, 48"), "the cards' borders came back")
    }

    func output() throws -> URL {
        if let path = ProcessInfo.processInfo.environment["CUE_EXPORT_RENDER_DIR"] { return URL(filePath: path) }
        return try ExportFixtures.folder()
    }

    struct Pixel: CustomStringConvertible {
        let red, green, blue, alpha: Double
        /// Composited over the slide's background colour, it is that colour.
        func matches(red r: Double, green g: Double, blue b: Double) -> Bool {
            let over = { (own: Double, under: Double) in own + under * (1 - alpha / 255) } // Premultiplied.
            return abs(over(red, r) - r) < 6 && abs(over(green, g) - g) < 6 && abs(over(blue, b) - b) < 6
        }
        var description: String { "rgba(\(Int(red)), \(Int(green)), \(Int(blue)), \(Int(alpha)))" }
    }

    static func image(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    /// The picture's premultiplied pixel at a canvas point, or nil outside it.
    static func pixel(_ image: CGImage, at point: CGPoint, box: CGRect) -> Pixel? {
        guard box.contains(point) else { return nil }
        let x = Int((point.x - box.minX) / box.width * Double(image.width))
        let y = Int((point.y - box.minY) / box.height * Double(image.height))
        var bytes = [UInt8](repeating: 0, count: 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            // Draw so that pixel (x, y) from the top lands on the 1×1 context.
            context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        }
        return Pixel(red: Double(bytes[0]), green: Double(bytes[1]), blue: Double(bytes[2]), alpha: Double(bytes[3]))
    }
}
