import CueCore
import Foundation
import Testing
@testable import CueImport

@Suite("Import service")
struct ImportServiceTests {
    static func sampleDeck() -> Data {
        var builder = PptxBuilder()
        builder.slides = (1...3).map { n in
            .init(shapes: PptxBuilder.textBox(id: 2, x: 0, y: 0, cx: 914_400, cy: 914_400,
                                              paragraphs: "<a:p>\(PptxConverterTests.run("Slide \(n) text"))</a:p>"),
                  notes: "Notes \(n)")
        }
        builder.slides[1].shapes += """
            <p:pic><p:nvPicPr><p:cNvPr id="9" name="P"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rIdP"/>
            </p:blipFill><p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="95250" cy="95250"/></a:xfrm></p:spPr></p:pic>
            """
        builder.slides[1].images = ["rIdP": TestImages.png()]
        return builder.data()
    }

    @Test func convertsNextToTheOriginalAndReopensAsACueDeck() async throws {
        let folder = TempFolder()
        let bytes = Self.sampleDeck()
        let original = try folder.file("Quarterly Review.pptx", bytes)
        let prepared = try await ImportService().prepare(original)

        #expect(prepared.htmlURL.lastPathComponent == "Quarterly Review (Cue).html")
        #expect(prepared.htmlURL.deletingLastPathComponent().resolvingSymlinksInPath() == folder.url.resolvingSymlinksInPath())
        let assets = folder.url.appendingPathComponent("Quarterly Review (Cue) assets")
        #expect(FileManager.default.fileExists(atPath: assets.appendingPathComponent("s2-rIdP.png").path))
        #expect(try Data(contentsOf: original) == bytes, "the original is never modified")

        let document = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(document.structure.adapter == .cue)
        #expect(document.structure.slides.count == 3)
        #expect(document.structure.slides.map(\.notes) == ["Notes 1", "Notes 2", "Notes 3"])
        #expect(document.structure.canvas == CanvasSize(width: 1280, height: 720))
    }

    @Test func reusesCuesCopyUntilAskedToConvertAgain() async throws {
        let folder = TempFolder()
        let original = try folder.file("Deck.pptx", Self.sampleDeck())
        let service = ImportService()
        let first = try await service.prepare(original)
        #expect(first.report != nil)

        let second = try await service.prepare(original)
        #expect(second.htmlURL == first.htmlURL)
        #expect(second.report == nil)
        #expect(second.reusedCopy == ImportService.ReusedCopy(originalIsNewer: false))

        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)], ofItemAtPath: original.path)
        #expect(try await service.prepare(original).reusedCopy?.originalIsNewer == true)
        let again = try await service.prepare(original, replacingCopy: true)
        #expect(again.htmlURL == first.htmlURL && again.report != nil)
    }

    @Test func neverOverwritesAFileCueDidNotWrite() async throws {
        let folder = TempFolder()
        let original = try folder.file("Deck.pptx", Self.sampleDeck())
        let theirs = try folder.file("Deck (Cue).html", Data("<html>someone else's file</html>".utf8))
        let prepared = try await ImportService().prepare(original)
        #expect(prepared.htmlURL.lastPathComponent == "Deck (Cue 2).html")
        #expect(try String(contentsOf: theirs, encoding: .utf8) == "<html>someone else's file</html>")
    }

    @Test func writesToCueImportsWhenTheFolderIsReadOnly() async throws {
        let folder = TempFolder(), fallback = TempFolder()
        let original = try folder.file("Deck.pptx", Self.sampleDeck())
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.url.path)
        let prepared = try await ImportService(fallbackFolder: fallback.url).prepare(original)
        #expect(prepared.htmlURL.deletingLastPathComponent().resolvingSymlinksInPath() == fallback.url.resolvingSymlinksInPath())
        #expect(prepared.report?.outputRelocated?.resolvingSymlinksInPath() == fallback.url.resolvingSymlinksInPath())
    }

    @Test func htmlOpensAsIs() async throws {
        let url = URL(fileURLWithPath: "/tmp/deck.html")
        let prepared = try await ImportService().prepare(url)
        #expect(prepared.htmlURL == url && prepared.report == nil)
    }

    @Test func pptWithoutKeynoteSaysWhy() async throws {
        let folder = TempFolder()
        let original = try folder.file("Old.ppt", Data("binary".utf8))
        var service = ImportService()
        service.keynote = KeynoteExporter.unavailable
        await #expect(throws: ImportError.needsKeynote("ppt")) { try await service.prepare(original) }
    }
}
