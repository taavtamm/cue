import CoreGraphics
import CueCore
import CueImport
import CueRender
import Foundation
import ImageIO
import Testing
@testable import CueExport

/// The .pptx writer on made-up slides: a valid package that Cue's own
/// PowerPoint importer reads back with the same slides, text and notes.
@Suite("PowerPoint writer")
struct PptxWriterTests {
    static func layout(_ json: String) throws -> ExportLayout {
        try JSONDecoder().decode(ExportLayout.self, from: Data(json.utf8))
    }

    static func jpeg() -> Data {
        let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        return ImageData.jpeg(context.makeImage()!)!
    }

    static let slideJSON = #"""
        {"canvas":{"x":0,"y":0,"width":1920,"height":1080},"width":1920,"height":1080,"images":[],
         "texts":[{"box":{"x":128,"y":180,"width":1000,"height":200},"align":"left","lineHeight":96,"wraps":true,
           "paragraphs":[[{"text":"AI that ","family":"Inter","weight":700,"italic":false,"underline":false,"size":88,
                           "color":"rgb(20, 20, 20)","letterSpacing":-2},
                          {"text":"works <here> & now.","family":"Inter","weight":700,"italic":true,"underline":true,"size":88,
                           "color":"rgba(106, 103, 97, 0.5)","letterSpacing":0}]]}]}
        """#

    static func slides() throws -> [ExportedSlide] {
        let picture = ExportedPicture(box: CGRect(x: 1200, y: 100, width: 400, height: 300), data: jpeg(),
                                      fileExtension: "jpeg", crop: PictureCrop(left: 0.1, top: 0, right: 0.1, bottom: 0), opacity: 0.8)
        return [
            ExportedSlide(layout: try layout(slideJSON), background: jpeg(), pictures: [picture], notes: "First notes\nSecond line"),
            ExportedSlide(layout: try layout(slideJSON), background: jpeg(), pictures: [], notes: ""),
        ]
    }

    @Test func packageHasEveryPartAndAllXMLIsWellFormed() throws {
        let archive = try ZipArchive(data: PptxWriter.data(slides: try Self.slides(), title: "Test <deck>"))
        let paths = Set(archive.entries.map(\.path))
        for required in ["[Content_Types].xml", "_rels/.rels", "ppt/presentation.xml", "ppt/_rels/presentation.xml.rels",
                         "ppt/slideMasters/slideMaster1.xml", "ppt/slideLayouts/slideLayout1.xml", "ppt/theme/theme1.xml",
                         "ppt/notesMasters/notesMaster1.xml", "ppt/slides/slide1.xml", "ppt/slides/slide2.xml",
                         "ppt/slides/_rels/slide1.xml.rels", "ppt/notesSlides/notesSlide1.xml",
                         "ppt/media/slide1-background.jpeg", "ppt/media/slide1-picture1.jpeg", "docProps/core.xml"] {
            #expect(paths.contains(required), "missing \(required)")
        }
        for entry in archive.entries where entry.path.hasSuffix(".xml") || entry.path.hasSuffix(".rels") {
            #expect(XMLCheck.isWellFormed(try archive.data(for: entry)), "\(entry.path) isn't well-formed XML")
        }
    }

    @Test func slideXMLCarriesTheRunsStyles() throws {
        let archive = try ZipArchive(data: PptxWriter.data(slides: try Self.slides(), title: "t"))
        let slide = String(decoding: try archive.data(for: "ppt/slides/slide1.xml"), as: UTF8.self)
        #expect(slide.contains(#"sz="4400""#), "88 px on a 1920 px canvas is 44 pt")
        #expect(slide.contains(#"b="1""#) && slide.contains(#"i="1""#) && slide.contains(#"u="sng""#))
        #expect(slide.contains(#"<a:srgbClr val="6A6761"><a:alpha val="50000"/>"#))
        #expect(slide.contains(#"typeface="Inter" pitchFamily="34""#), "a sans-serif hint for apps without Inter")
        #expect(slide.contains("works &lt;here&gt; &amp; now."))
        #expect(slide.contains(#"<a:srcRect l="10000" t="0" r="10000" b="0"/>"#))
        #expect(slide.contains(#"<a:alphaModFix amt="80000"/>"#))
    }

    @Test func cuesOwnImporterReadsItBack() async throws {
        let folder = try ExportFixtures.folder()
        let url = folder.appending(path: "Export.pptx")
        try PptxWriter.data(slides: try Self.slides(), title: "Export").write(to: url)
        let prepared = try await ImportService().prepare(url)
        let deck = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(deck.structure.slides.count == 2)
        #expect(deck.structure.slides[0].notes == "First notes\nSecond line")
        #expect(deck.source.contains("AI that") && deck.source.contains("works &lt;here&gt; &amp; now."))
    }
}

@Suite("Text box frames")
struct TextFrameTests {
    static func box(align: String, wraps: Bool) throws -> ExportLayout.TextBox {
        let json = #"{"box":{"x":1700,"y":980,"width":40,"height":24},"align":"\#(align)","lineHeight":24,"wraps":\#(wraps),"#
            + #""paragraphs":[[{"text":"03","family":"Inter","weight":400,"italic":false,"underline":false,"size":20,"#
            + #""color":"rgb(0,0,0)","letterSpacing":0}]]}"#
        return try JSONDecoder().decode(ExportLayout.TextBox.self, from: Data(json.utf8))
    }

    @Test func singleLinesGetRoomAwayFromTheirAlignment() throws {
        let right = PptxTextXML.frameWidth(try Self.box(align: "right", wraps: false))
        #expect(right.x + right.width == 1740, "right-aligned text keeps its right edge")
        #expect(right.width > 40)
        let left = PptxTextXML.frameWidth(try Self.box(align: "left", wraps: false))
        #expect(left.x == 1700 && left.width > 40)
        let wrapping = PptxTextXML.frameWidth(try Self.box(align: "left", wraps: true))
        #expect(abs(wrapping.width - 40.8) < 0.001)
    }
}
