import CoreGraphics
import CueRender
import Foundation
import Testing
@testable import CueExport

/// Computed CSS can be any number. Writing it as PowerPoint never traps;
/// values land in range instead.
@Suite("Absurd numbers in export")
struct AbsurdNumberTests {
    static let huge = 1e308
    static let scale = PptxScale(canvasWidth: 1920)

    @Test func conversionsClampInsteadOfTrapping() {
        #expect(OOXMLNumber.int(.nan) == 0)
        #expect(OOXMLNumber.int(.infinity) == Int(Int32.max))
        #expect(OOXMLNumber.int(-Self.huge) == Int(Int32.min))
        #expect(OOXMLNumber.int(1e9, in: 0...50_000) == 50_000)
        #expect(OOXMLNumber.int(.nan, in: 0...255) == 0)
        #expect(OOXMLNumber.angle(degrees: -90) == 16_200_000)
        #expect(OOXMLNumber.angle(degrees: 720.5) == 30_000)
        #expect(OOXMLNumber.angle(degrees: 359.999_999_9) == 0)
        #expect(OOXMLNumber.angle(degrees: .infinity) == 0)
        #expect(OOXMLNumber.angle(degrees: Self.huge) < 21_600_000)
        #expect(Self.scale.emu(Self.huge) == Int(Int32.max))
        #expect(Self.scale.centipoints(-Self.huge) == Int(Int32.min))
        #expect(PptxScale(canvasWidth: .nan).emu(1) > 0)
        #expect(PptxFillXML.angle(css: -Self.huge) >= 0)
    }

    @Test func aShapeWithAbsurdGeometryStillWrites() throws {
        let box = #"{"x":1e308,"y":-1e308,"width":1e308,"height":1e308}"#
        let fields = #""fill":{"type":"linear","angle":1e308,"stops":[{"color":"rgb(0,0,0)","position":1e308},"#
            + #"{"color":"rgb(255,255,255)","position":-1e308}]},"#
            + #""line":{"width":1e308,"color":"rgb(1,2,3)","dash":"dash"},"#
            + #""sides":[{"width":1e308,"color":"rgb(1,2,3)","dash":"solid"},null,null,null],"#
            + #""shadow":{"color":"rgba(0,0,0,0.5)","x":1e308,"y":-1e308,"blur":1e308}"#
        for geometry in ["rect", "roundRect", "ellipse", "line"] {
            let shape = try PptxShapeTests.shape(fields, box: box, geometry: geometry, rotation: 1e308, radius: 1e308)
            let xml = PptxShapeXML.xml(shape, id: 2, scale: Self.scale).xml
            #expect(XMLCheck.isWellFormed(Data(PptxShapeTests.wrap(xml).utf8)), "\(geometry)")
        }
    }

    @Test func pictureAndColourExtremes() {
        let crop = PictureCrop(left: Self.huge, top: -Self.huge, right: .nan, bottom: .infinity)
        let picture = PptxSlideXML.picture(
            rid: "rId1", id: 3, name: "p", box: CGRect(x: Self.huge, y: 0, width: Self.huge, height: 1),
            crop: crop, opacity: -Self.huge, scale: Self.scale
        )
        #expect(picture.contains("<a:srcRect"))
        let digits = String(repeating: "9", count: 400) // Parses as infinity.
        let colour = CSSColour("rgb(\(digits), 300, 12)")
        #expect(colour?.hex == "FFFF0C")
        #expect(!PptxTextXML.fill("rgba(1, 2, 3, 0.5)").isEmpty)
    }
}
