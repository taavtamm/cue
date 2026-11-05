import CoreGraphics
import CueImport
import CueRender
import Foundation
import Testing
@testable import CueExport

/// Boxes as PowerPoint shapes: geometry, fills, outlines, shadows, the
/// slide background, and paint order with text and pictures.
@Suite("PowerPoint shapes")
struct PptxShapeTests {
    static let scale = PptxScale(canvasWidth: 1920) // 6 350 EMU per pixel.

    static func shape(_ fields: String, box: String = #"{"x":100,"y":200,"width":400,"height":200}"#,
                      geometry: String = "rect", rotation: Double = 0, radius: Double = 0,
                      opacity: Double = 1) throws -> ExportLayout.Shape {
        let json = #"{"box":\#(box),"rotation":\#(rotation),"geometry":"\#(geometry)","radius":\#(radius),"#
            + #""opacity":\#(opacity),"order":0"#
            + (fields.isEmpty ? "" : ",\(fields)") + "}"
        return try JSONDecoder().decode(ExportLayout.Shape.self, from: Data(json.utf8))
    }

    static func xml(_ shape: ExportLayout.Shape) -> String { PptxShapeXML.xml(shape, id: 2, scale: scale).xml }

    @Test func rectangleWithASeeThroughFill() throws {
        let xml = Self.xml(try Self.shape(#""fill":{"type":"solid","color":"rgba(115, 114, 108, 0.12)"}"#, opacity: 0.5))
        #expect(xml.contains(#"<a:prstGeom prst="rect">"#))
        #expect(xml.contains(#"<a:off x="635000" y="1270000"/><a:ext cx="2540000" cy="1270000"/>"#))
        #expect(xml.contains(#"<a:solidFill><a:srgbClr val="73726C"><a:alpha val="6000"/></a:srgbClr></a:solidFill>"#),
                "the colour's alpha times the opacity")
        #expect(xml.contains("<a:ln><a:noFill/></a:ln>"))
        #expect(XMLCheck.isWellFormed(Data(Self.wrap(xml).utf8)))
    }

    @Test func roundedCornersBecomeARoundRectWithTheRightAdjustment() throws {
        let shape = try Self.shape(#""line":{"width":1,"color":"rgb(58, 54, 48)","dash":"solid"}"#,
                                   geometry: "roundRect", radius: 8)
        let xml = Self.xml(shape)
        #expect(xml.contains(#"<a:prstGeom prst="roundRect"><a:avLst><a:gd name="adj" fmla="val 4000"/>"#), "8 ÷ 200")
        #expect(xml.contains(#"<a:noFill/><a:ln w="6350"><a:solidFill><a:srgbClr val="3A3630"></a:srgbClr></a:solidFill></a:ln>"#))
    }

    @Test func circlesBecomeEllipses() throws {
        let xml = Self.xml(try Self.shape(#""fill":{"type":"solid","color":"rgb(169, 184, 255)"}"#, geometry: "ellipse"))
        #expect(xml.contains(#"prst="ellipse""#) && xml.contains(#"val="A9B8FF""#))
    }

    @Test func dashedAndDottedOutlines() throws {
        let dashed = Self.xml(try Self.shape(#""line":{"width":2,"color":"rgb(0, 0, 0)","dash":"dash"}"#))
        #expect(dashed.contains(#"<a:ln w="12700">"#) && dashed.contains(#"<a:prstDash val="dash"/>"#))
        let dotted = Self.xml(try Self.shape(#""line":{"width":2,"color":"rgb(0, 0, 0)","dash":"dot"}"#))
        #expect(dotted.contains(#"<a:prstDash val="sysDot"/>"#))
    }

    @Test func thinBoxesBecomeLinesThroughTheirMiddle() throws {
        let shape = try Self.shape(#""fill":{"type":"solid","color":"rgb(169, 184, 255)"}"#,
                                   box: #"{"x":100,"y":500,"width":800,"height":2}"#, geometry: "line")
        let xml = Self.xml(shape)
        #expect(xml.hasPrefix("<p:cxnSp>") && xml.contains(#"prst="line""#))
        #expect(xml.contains(#"<a:off x="635000" y="3181350"/><a:ext cx="5080000" cy="0"/>"#), "y = 501 px")
        #expect(xml.contains(#"<a:ln w="12700"><a:solidFill><a:srgbClr val="A9B8FF">"#))
    }

    @Test func bordersThatDifferPerSideAreLines() throws {
        let shape = try Self.shape(#""sides":[null,null,null,{"width":4,"color":"rgb(169, 184, 255)","dash":"solid"}]"#)
        let written = PptxShapeXML.xml(shape, id: 2, scale: Self.scale)
        #expect(written.count == 2, "the box, then its left border")
        #expect(written.xml.contains(#"<p:cNvPr id="3" name="Border 3"/>"#))
        #expect(written.xml.contains(#"<a:off x="647700" y="1270000"/><a:ext cx="0" cy="1270000"/>"#), "x = 102 px")
        #expect(written.xml.contains(#"<a:ln w="25400">"#))
    }

    @Test func linearGradientsKeepTheirAngleAndStops() throws {
        let xml = Self.xml(try Self.shape(#""fill":{"type":"linear","angle":135,"stops":["#
            + #"{"color":"rgb(255, 0, 0)","position":0},{"color":"rgba(0, 0, 255, 0.5)","position":0.6}]}"#))
        #expect(xml.contains(#"<a:gs pos="0"><a:srgbClr val="FF0000"></a:srgbClr></a:gs>"#))
        #expect(xml.contains(#"<a:gs pos="60000"><a:srgbClr val="0000FF"><a:alpha val="50000"/></a:srgbClr></a:gs>"#))
        #expect(xml.contains(#"<a:lin ang="2700000" scaled="0"/>"#), "CSS 135° (towards bottom right) is DrawingML 45°")
        #expect(PptxFillXML.angle(css: 0) == 16_200_000 && PptxFillXML.angle(css: 180) == 5_400_000)
    }

    @Test func boxShadowsAreOuterShadows() throws {
        let xml = Self.xml(try Self.shape(#""fill":{"type":"solid","color":"rgb(255, 255, 255)"},"#
            + #""shadow":{"color":"rgba(0, 0, 0, 0.25)","x":0,"y":8,"blur":24}"#))
        #expect(xml.contains(#"<a:effectLst><a:outerShdw blurRad="152400" dist="50800" dir="5400000" algn="ctr" rotWithShape="0">"#
            + #"<a:srgbClr val="000000"><a:alpha val="25000"/></a:srgbClr></a:outerShdw></a:effectLst>"#))
    }

    @Test func rotationTurnsTheFrame() throws {
        let fill = #""fill":{"type":"solid","color":"rgb(0, 0, 0)"}"#
        #expect(Self.xml(try Self.shape(fill, rotation: 15)).contains(#"<a:xfrm rot="900000">"#))
        #expect(Self.xml(try Self.shape(fill, rotation: -15)).contains(#"<a:xfrm rot="20700000">"#))
    }

    static func wrap(_ shapes: String) -> String {
        "<p:spTree \(PptxStaticParts.ns)>\(shapes)</p:spTree>"
    }
}
