import CoreGraphics
import CueCore
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// One slide per PDF page, each drawn to a 2× PNG. Looks exactly like the
/// PDF; only notes can be edited.
struct PDFImporter: DeckImporter {
    func makeDeck(from url: URL, assets: AssetStore, report: inout ImportReport) async throws -> ImportedDeck {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else {
            throw ImportError.damaged("the PDF has no readable pages")
        }
        if document.isEncrypted && !document.isUnlocked { throw ImportError.damaged("the PDF is password-protected") }
        guard let first = document.page(at: 1) else { throw ImportError.empty }
        let canvas = Self.cssSize(of: first)
        var deck = ImportedDeck(title: url.deletingPathExtension().lastPathComponent,
                                canvas: CanvasSize(width: canvas.width, height: canvas.height))
        deck.isPresentOnly = true
        for number in 1...document.numberOfPages {
            guard let page = document.page(at: number), let png = Self.render(page, scale: 2) else {
                report.note("This page couldn't be drawn", slide: number)
                continue
            }
            let source = assets.add(png, key: "page-\(number)", preferredName: "page-\(number).png")
            let size = Self.cssSize(of: page)
            let fit = min(canvas.width / size.width, canvas.height / size.height)
            let frame = Rect(x: (canvas.width - size.width * fit) / 2, y: (canvas.height - size.height * fit) / 2,
                             width: size.width * fit, height: size.height * fit)
            let element = ImportedElement(name: "Page \(number)", frame: frame,
                                          content: .image(source: source, crop: nil, alt: "Page \(number)"))
            deck.slides.append(ImportedSlide(label: "Page \(number)", elements: [element]))
        }
        report.note("PDF pages are pictures: they present exactly, and only notes can be edited.")
        return deck
    }

    /// Page size in CSS pixels (1 pt = 4/3 px), after the page's rotation.
    static func cssSize(of page: CGPDFPage) -> CGSize {
        let box = page.getBoxRect(.cropBox)
        let turned = page.rotationAngle % 180 != 0
        let width = (turned ? box.height : box.width) * 4 / 3
        let height = (turned ? box.width : box.height) * 4 / 3
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    static func render(_ page: CGPDFPage, scale: CGFloat) -> Data? {
        let size = cssSize(of: page)
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)
        guard let context = CGContext(
            data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: pixels))
        // getDrawingTransform never scales up, so scale the context first and
        // let it handle only the box origin and the page's rotation.
        let points = CGSize(width: size.width * 3 / 4, height: size.height * 3 / 4)
        context.scaleBy(x: pixels.width / points.width, y: pixels.height / points.height)
        let target = CGRect(origin: .zero, size: points)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
