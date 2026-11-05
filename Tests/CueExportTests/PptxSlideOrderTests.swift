import CoreGraphics
import CueCore
import CueImport
import CueRender
import Foundation
import Testing
@testable import CueExport

/// A slide with a flat background, a card and its text: the background is
/// the slide's own, the card a shape beneath its text, and there's no
/// flattened picture when nothing needs one.
@Suite("PowerPoint slide background and paint order")
struct PptxSlideOrderTests {
    static let json = #"""
        {"canvas":{"x":0,"y":0,"width":1920,"height":1080},"width":1920,"height":1080,
         "background":{"type":"solid","color":"rgb(20, 18, 16)"},"unsupported":0,"keptShapes":0,"needsPicture":false,
         "shapes":[{"box":{"x":128,"y":700,"width":400,"height":240},"rotation":0,"geometry":"roundRect","radius":8,"opacity":1,
                    "line":{"width":1,"color":"rgb(58, 54, 48)","dash":"solid"},"order":0},
                   {"box":{"x":1000,"y":100,"width":600,"height":400},"rotation":0,"geometry":"rect","radius":0,"opacity":1,
                    "fill":{"type":"solid","color":"rgb(255, 255, 255)"},"order":2}],
         "images":[],
         "texts":[{"box":{"x":158,"y":728,"width":340,"height":40},"align":"left","lineHeight":40,"wraps":false,"order":1,
           "paragraphs":[[{"text":"01 · CLEAR","family":"Inter","weight":600,"italic":false,"underline":false,"size":28,
                           "color":"rgb(76, 194, 143)","letterSpacing":2}]]}]}
        """#

    static func slide(gradient: Bool = false) throws -> ExportedSlide {
        var text = json
        if gradient {
            text = text.replacingOccurrences(of: #""background":{"type":"solid","color":"rgb(20, 18, 16)"}"#, with:
                #""background":{"type":"linear","angle":180,"stops":[{"color":"rgb(0, 0, 0)","position":0},{"color":"rgb(40, 40, 40)","position":1}]}"#)
        }
        let layout = try JSONDecoder().decode(ExportLayout.self, from: Data(text.utf8))
        let picture = ExportedPicture(box: CGRect(x: 1100, y: 150, width: 200, height: 100), data: PptxWriterTests.jpeg(),
                                      fileExtension: "jpeg", order: 3)
        return ExportedSlide(layout: layout, background: nil, pictures: [picture], notes: "")
    }

    @Test func flatFillsAreTheSlideBackground() throws {
        let xml = PptxSlideXML.slide(try Self.slide(), scale: PptxShapeTests.scale)
        #expect(xml.contains(#"<p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="141210"></a:srgbClr></a:solidFill><a:effectLst/></p:bgPr></p:bg><p:spTree>"#))
        let gradient = PptxSlideXML.slide(try Self.slide(gradient: true), scale: PptxShapeTests.scale)
        #expect(gradient.contains(#"<p:bg><p:bgPr><a:gradFill rotWithShape="1">"#) && gradient.contains(#"<a:lin ang="5400000""#))
        #expect(XMLCheck.isWellFormed(Data(xml.utf8)) && XMLCheck.isWellFormed(Data(gradient.utf8)))
    }

    @Test func partsKeepTheirPaintOrder() throws {
        let xml = PptxSlideXML.slide(try Self.slide(), scale: PptxShapeTests.scale)
        let card = try #require(xml.range(of: #"prst="roundRect""#)).lowerBound
        let text = try #require(xml.range(of: "01 · CLEAR")).lowerBound
        let panel = try #require(xml.range(of: #"<a:srgbClr val="FFFFFF">"#)).lowerBound
        let picture = try #require(xml.range(of: "<p:pic>")).lowerBound
        #expect(card < text && text < panel && panel < picture, "card, its text, the panel, the picture on the panel")
    }

    @Test func noFlattenedPictureWhenNothingNeedsOne() throws {
        let slide = try Self.slide()
        #expect(!PptxSlideXML.slide(slide, scale: PptxShapeTests.scale).contains("Slide picture (flattened)"))
        let relationships = PptxSlideXML.slideRelationships(slide, number: 1)
        #expect(!relationships.contains("background") && relationships.contains(#"Id="rId3""#))
        let archive = try ZipArchive(data: PptxWriter.data(slides: [slide], title: "t"))
        #expect(!archive.entries.contains { $0.path.contains("background") })
        for entry in archive.entries where entry.path.hasSuffix(".xml") || entry.path.hasSuffix(".rels") {
            #expect(XMLCheck.isWellFormed(try archive.data(for: entry)), "\(entry.path)")
        }
    }

    @Test func cuesImporterReadsTheShapesBack() async throws {
        let url = try ExportFixtures.folder().appending(path: "Shapes.pptx")
        try PptxWriter.data(slides: [try Self.slide()], title: "Shapes").write(to: url)
        let prepared = try await ImportService().prepare(url)
        let deck = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(deck.structure.slides.count == 1)
        let source = deck.source.lowercased()
        #expect(source.contains("01 · clear"))
        #expect(source.contains("#141210") || source.contains("20, 18, 16") || source.contains("20,18,16"), "the background")
        #expect(source.contains("#3a3630") || source.contains("58, 54, 48") || source.contains("58,54,48"), "the card's border")
    }
}
