import CueRender
import Foundation

/// A slide's boxes as editable PowerPoint shapes: rectangles, rounded
/// rectangles, ellipses and lines, with fills, outlines and shadows.
enum PptxShapeXML {
    /// The shape's `<p:sp>` and, for borders that differ per side, one line
    /// per side. Ids run from `id`; `count` is how many were used.
    static func xml(_ shape: ExportLayout.Shape, id: Int, scale: PptxScale) -> (xml: String, count: Int) {
        let box = shape.box
        if shape.geometry == "line" {
            let vertical = box.height > box.width
            let line = ExportLayout.Line(width: min(box.width, box.height), color: shape.fill?.color ?? "", dash: "solid")
            let from = vertical ? CGPoint(x: box.x + box.width / 2, y: box.y) : CGPoint(x: box.x, y: box.y + box.height / 2)
            let to = vertical ? CGPoint(x: from.x, y: box.y + box.height) : CGPoint(x: box.x + box.width, y: from.y)
            let segment = Segment(from: from, to: to, line: line, rotation: shape.rotation)
            return (lineShape(segment, opacity: shape.opacity, id: id, name: "Line \(id)", scale: scale), 1)
        }
        let outline = shape.line.map { ln(width: $0.width, line: $0, opacity: shape.opacity, scale: scale) }
            ?? "<a:ln><a:noFill/></a:ln>"
        var xml = "<p:sp><p:nvSpPr><p:cNvPr id=\"\(id)\" name=\"\(name(shape.geometry)) \(id)\"/>"
            + "<p:cNvSpPr/><p:nvPr/></p:nvSpPr>"
            + "<p:spPr>\(frame(box, rotation: shape.rotation, scale: scale))\(geometry(shape))"
            + PptxFillXML.fill(shape.fill, opacity: shape.opacity) + outline
            + shadow(shape.shadow, opacity: shape.opacity, scale: scale)
            + "</p:spPr>\(emptyText)</p:sp>"
        var count = 1
        for segment in sideLines(shape) {
            xml += lineShape(segment, opacity: shape.opacity, id: id + count, name: "Border \(id + count)", scale: scale)
            count += 1
        }
        return (xml, count)
    }

    /// A straight stretch of outline, in canvas pixels.
    struct Segment {
        let from, to: CGPoint
        let line: ExportLayout.Line
        var rotation: Double = 0
    }

    /// An empty text body, so PowerPoint lets people type into the shape.
    static let emptyText = "<p:txBody><a:bodyPr rtlCol=\"0\" anchor=\"ctr\"/><a:lstStyle/>"
        + "<a:p><a:endParaRPr lang=\"en-US\" dirty=\"0\"/></a:p></p:txBody>"

    static func name(_ geometry: String) -> String {
        ["roundRect": "Rounded Rectangle", "ellipse": "Oval"][geometry] ?? "Rectangle"
    }

    static func geometry(_ shape: ExportLayout.Shape) -> String {
        guard shape.geometry == "roundRect" else {
            return "<a:prstGeom prst=\"\(shape.geometry == "ellipse" ? "ellipse" : "rect")\"><a:avLst/></a:prstGeom>"
        }
        let side = min(shape.box.width, shape.box.height)
        let adj = side > 0 ? OOXMLNumber.int(shape.radius / side * 100_000, in: 0...50_000) : 0
        return "<a:prstGeom prst=\"roundRect\"><a:avLst><a:gd name=\"adj\" fmla=\"val \(adj)\"/></a:avLst></a:prstGeom>"
    }

    static func frame(_ box: ExportLayout.Box, rotation: Double, scale: PptxScale) -> String {
        let turn = OOXMLNumber.angle(degrees: rotation)
        let rot = turn == 0 ? "" : " rot=\"\(turn)\""
        return "<a:xfrm\(rot)><a:off x=\"\(scale.emu(box.x))\" y=\"\(scale.emu(box.y))\"/>"
            + "<a:ext cx=\"\(max(1, scale.emu(box.width)))\" cy=\"\(max(1, scale.emu(box.height)))\"/></a:xfrm>"
    }

    /// `<a:ln>`: width in EMU, colour, dashes.
    static func ln(width: Double, line: ExportLayout.Line, opacity: Double, scale: PptxScale) -> String {
        guard let colour = PptxFillXML.colour(line.color, opacity: opacity) else { return "<a:ln><a:noFill/></a:ln>" }
        let dash = ["dash": "<a:prstDash val=\"dash\"/>", "dot": "<a:prstDash val=\"sysDot\"/>"][line.dash] ?? ""
        return "<a:ln w=\"\(max(1, scale.emu(width)))\"><a:solidFill>\(colour)</a:solidFill>\(dash)</a:ln>"
    }

    /// An outer shadow: CSS offset as distance and direction, blur as radius.
    static func shadow(_ shadow: ExportLayout.Shadow?, opacity: Double, scale: PptxScale) -> String {
        guard let shadow, let colour = PptxFillXML.colour(shadow.color, opacity: opacity) else { return "" }
        let distance = (shadow.x * shadow.x + shadow.y * shadow.y).squareRoot()
        let direction = atan2(shadow.y, shadow.x) * 180 / .pi
        return "<a:effectLst><a:outerShdw blurRad=\"\(scale.emu(shadow.blur))\" dist=\"\(scale.emu(distance))\""
            + " dir=\"\(OOXMLNumber.angle(degrees: direction))\" algn=\"ctr\" rotWithShape=\"0\">"
            + "\(colour)</a:outerShdw></a:effectLst>"
    }

    /// Borders that differ per side, each a line along the middle of its border.
    static func sideLines(_ shape: ExportLayout.Shape) -> [Segment] {
        guard let sides = shape.sides, sides.count == 4 else { return [] }
        let b = shape.box
        var lines: [Segment] = []
        if let top = sides[0] {
            let y = b.y + top.width / 2
            lines.append(Segment(from: CGPoint(x: b.x, y: y), to: CGPoint(x: b.x + b.width, y: y), line: top))
        }
        if let right = sides[1] {
            let x = b.x + b.width - right.width / 2
            lines.append(Segment(from: CGPoint(x: x, y: b.y), to: CGPoint(x: x, y: b.y + b.height), line: right))
        }
        if let bottom = sides[2] {
            let y = b.y + b.height - bottom.width / 2
            lines.append(Segment(from: CGPoint(x: b.x, y: y), to: CGPoint(x: b.x + b.width, y: y), line: bottom))
        }
        if let left = sides[3] {
            let x = b.x + left.width / 2
            lines.append(Segment(from: CGPoint(x: x, y: b.y), to: CGPoint(x: x, y: b.y + b.height), line: left))
        }
        return lines
    }

    /// A straight line (horizontal or vertical) as a connector shape.
    static func lineShape(_ segment: Segment, opacity: Double, id: Int, name: String, scale: PptxScale) -> String {
        let from = segment.from, to = segment.to
        let box = ExportLayout.Box(x: min(from.x, to.x), y: min(from.y, to.y),
                                   width: abs(to.x - from.x), height: abs(to.y - from.y))
        let turn = OOXMLNumber.angle(degrees: segment.rotation)
        let rot = turn == 0 ? "" : " rot=\"\(turn)\""
        let xfrm = "<a:xfrm\(rot)><a:off x=\"\(scale.emu(box.x))\" y=\"\(scale.emu(box.y))\"/>"
            + "<a:ext cx=\"\(scale.emu(box.width))\" cy=\"\(scale.emu(box.height))\"/></a:xfrm>"
        return "<p:cxnSp><p:nvCxnSpPr><p:cNvPr id=\"\(id)\" name=\"\(name)\"/><p:cNvCxnSpPr/><p:nvPr/></p:nvCxnSpPr>"
            + "<p:spPr>\(xfrm)<a:prstGeom prst=\"line\"><a:avLst/></a:prstGeom>"
            + ln(width: segment.line.width, line: segment.line, opacity: opacity, scale: scale) + "</p:spPr></p:cxnSp>"
    }
}
