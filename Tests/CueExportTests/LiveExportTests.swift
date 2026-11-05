import AppKit
import CueCore
import CueImport
import Foundation
import PDFKit
import Testing
@testable import CueExport

/// Real exports of the Fernwick deck, rendered offscreen.
/// Set CUE_EXPORT_RENDER_DIR to keep the files for a visual check.
@Suite("Exporting the Fernwick deck", .serialized)
@MainActor
struct LiveExportTests {
    func outputFolder() throws -> URL {
        if let path = ProcessInfo.processInfo.environment["CUE_EXPORT_RENDER_DIR"] { return URL(filePath: path) }
        return try ExportFixtures.folder()
    }

    @Test func powerPointIsEditableAndReadsBack() async throws {
        let document = try ExportFixtures.demo-deck()
        let url = try outputFolder().appending(path: "demo-deck.pptx")
        var steps: [Int] = []
        let result = try await DeckExport.powerPoint(document, to: url) { done, _ in steps.append(done) }
        #expect(result.slides == 12)
        #expect(steps.last == 12)
        #expect(result.flattened.count == 12)
        #expect(result.flattened[2] > 0, "slide 3's live embed and logo stay in its picture")
        #expect(try Data(contentsOf: document.fileURL) == Data(contentsOf: ExportFixtures.repoRoot.appending(path: "fixtures/demo-deck.html")),
                "the deck isn't changed")

        let archive = try ZipArchive(data: Data(contentsOf: url))
        for entry in archive.entries where entry.path.hasSuffix(".xml") || entry.path.hasSuffix(".rels") {
            #expect(XMLCheck.isWellFormed(try archive.data(for: entry)), "\(entry.path)")
        }
        let first = String(decoding: try archive.data(for: "ppt/slides/slide1.xml"), as: UTF8.self)
        #expect(first.contains(">Plans that ") && first.contains(">hold up.<"), "slide 1's headline is a real text box")
        #expect(first.contains(#"<a:srgbClr val="6A6761">"#), "and keeps its grey")

        let prepared = try await ImportService().prepare(url)
        let back = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(back.structure.slides.count == 12)
        #expect(back.structure.slides.map(\.notes) == document.structure.slides.map(\.notes))
        #expect(back.source.contains("One question, answered."))
    }

    @Test func pdfHasOnePagePerSlide() async throws {
        let document = try ExportFixtures.demo-deck()
        let url = try outputFolder().appending(path: "demo-deck.pdf")
        let result = try await DeckExport.pdf(document, to: url)
        let pdf = try #require(PDFDocument(url: url))
        #expect(result.slides == 12 && pdf.pageCount == 12)
        let box = try #require(pdf.page(at: 0)?.bounds(for: .mediaBox))
        #expect(abs(box.width / box.height - 16.0 / 9.0) < 0.01)
        #expect((pdf.page(at: 2)?.string ?? "").contains("One question, answered"), "text stays text")
    }

    @Test func imagesAreOnePNGPerSlide() async throws {
        let document = try ExportFixtures.demo-deck()
        let folder = try outputFolder().appending(path: "demo-deck images")
        _ = try await DeckExport.images(document, to: folder, scale: 1)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(files.count == 12)
        #expect(files.first == "demo-deck – 01.png")
        let image = try #require(NSImage(contentsOf: folder.appending(path: files[0])))
        #expect(image.representations.first?.pixelsWide == 1920)
    }
}
