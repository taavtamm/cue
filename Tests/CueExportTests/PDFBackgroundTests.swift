import AppKit
import CueCore
import Foundation
import PDFKit
import Testing
@testable import CueExport

/// A PDF page looks like the slide: backgrounds drawn with CSS (the slide's
/// own, a panel's, a gradient) are in it, and see-through gradients and
/// gradient masks stay see-through (WebKit's PDF alone makes them solid).
@Suite("PDF backgrounds", .serialized)
@MainActor
struct PDFBackgroundTests {
    static let deck = """
    <!doctype html><html><head><style>
    html, body { margin: 0; background: rgb(41, 45, 61); }
    section { width: 1920px; height: 1080px; position: relative; background: rgb(41, 45, 61); color: white; }
    .panel { position: absolute; left: 960px; top: 0; width: 960px; height: 540px; background-color: rgb(220, 30, 30); }
    .fade { position: absolute; left: 0; top: 540px; width: 960px; height: 540px;
            background-image: linear-gradient(rgb(30, 160, 60), rgb(30, 160, 60)); }
    .photo { position: absolute; left: 960px; top: 540px; width: 960px; height: 540px; background: rgb(240, 200, 40); }
    .veil { position: absolute; left: 960px; top: 540px; width: 960px; height: 540px;
            color: white; font-size: 40px;
            background-image: linear-gradient(90deg, rgba(0, 0, 255, 1) 0%, rgba(0, 0, 255, 0) 100%); }
    .masked { position: absolute; left: 0; top: 0; width: 480px; height: 540px; background: rgb(30, 30, 230);
              -webkit-mask-image: linear-gradient(90deg, black, transparent);
              mask-image: linear-gradient(90deg, black, transparent); }
    </style></head><body>
    <section><h1>Dark slide</h1><div class="panel"></div><div class="fade"></div>
    <div class="photo"></div><div class="veil">Fades into the photo</div><div class="masked"></div></section>
    </body></html>
    """

    @Test func backgroundsAreDrawn() async throws {
        let document = try ExportFixtures.deck(Self.deck)
        let url = try ExportFixtures.folder().appending(path: "deck.pdf")
        _ = try await DeckExport.pdf(document, to: url)
        let page = try #require(PDFDocument(url: url)?.page(at: 0))
        let bitmap = try #require(Self.bitmap(page))
        let dark = try #require(Self.color(bitmap, x: 0.4, y: 0.25))
        let red = try #require(Self.color(bitmap, x: 0.75, y: 0.25))
        let green = try #require(Self.color(bitmap, x: 0.25, y: 0.75))
        #expect(dark.brightnessComponent < 0.35, "the slide's dark background: \(dark)")
        #expect(red.redComponent > 0.7 && red.greenComponent < 0.3, "the red panel: \(red)")
        #expect(green.greenComponent > 0.5 && green.redComponent < 0.3, "the gradient: \(green)")

        let photo = try #require(Self.color(bitmap, x: 0.97, y: 0.75))
        #expect(photo.redComponent > 0.8 && photo.greenComponent > 0.6, "the fade lets the photo through: \(photo)")
        let fadeStart = try #require(Self.color(bitmap, x: 0.52, y: 0.95))
        #expect(fadeStart.blueComponent > 0.8 && fadeStart.redComponent < 0.3, "and starts solid: \(fadeStart)")
        let maskEnd = try #require(Self.color(bitmap, x: 0.24, y: 0.25))
        #expect(maskEnd.brightnessComponent < 0.35 && maskEnd.blueComponent < 0.4,
                "the mask fades to the dark slide: \(maskEnd)")
        #expect((page.string ?? "").contains("Fades into the photo"), "text on a flattened box stays text")
        #expect(try Data(contentsOf: document.fileURL) == Data(Self.deck.utf8), "the deck isn't changed")
    }

    /// The page drawn at 480 × 270.
    static func bitmap(_ page: PDFPage) -> NSBitmapImageRep? {
        let size = NSSize(width: 480, height: 270)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 480, pixelsHigh: 270, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        context.cgContext.setFillColor(NSColor.white.cgColor)
        context.cgContext.fill(CGRect(origin: .zero, size: size))
        context.cgContext.scaleBy(x: size.width / bounds.width, y: size.height / bounds.height)
        page.draw(with: .mediaBox, to: context.cgContext)
        return rep
    }

    /// The colour at a fraction of the page, from its top left.
    static func color(_ rep: NSBitmapImageRep, x: Double, y: Double) -> NSColor? {
        rep.colorAt(x: Int(x * Double(rep.pixelsWide)), y: Int(y * Double(rep.pixelsHigh)))?.usingColorSpace(.deviceRGB)
    }
}
