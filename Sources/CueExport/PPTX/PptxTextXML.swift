import CueRender
import Foundation

/// A text box as DrawingML: one `p:sp` with the box's paragraphs and runs.
enum PptxTextXML {
    static func shape(_ text: ExportLayout.TextBox, id: Int, scale: PptxScale) -> String {
        let (x, width) = frameWidth(text)
        let wrap = text.wraps ? "square" : "none"
        let paragraphs = text.paragraphs.map { paragraph(runs: $0, text: text, scale: scale) }.joined()
        return "<p:sp><p:nvSpPr><p:cNvPr id=\"\(id)\" name=\"Text \(id)\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>"
            + "<p:spPr>\(PptxSlideXML.frame(x: x, y: text.box.y, width: width, height: text.box.height, scale: scale))"
            + "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>"
            + "<p:txBody><a:bodyPr wrap=\"\(wrap)\" lIns=\"0\" tIns=\"0\" rIns=\"0\" bIns=\"0\" rtlCol=\"0\" anchor=\"t\">"
            + "<a:noAutofit/></a:bodyPr><a:lstStyle/>\(paragraphs)</p:txBody></p:sp>"
    }

    /// The box's left edge and width. A little room for font metrics that
    /// differ from the browser's; single lines get more, growing away from
    /// their alignment, because some apps wrap even when told not to.
    static func frameWidth(_ text: ExportLayout.TextBox) -> (x: Double, width: Double) {
        let box = text.box
        guard !text.wraps else { return (box.x, box.width * 1.02) }
        let size = text.paragraphs.first?.first?.size ?? 16
        let extra = box.width * 0.15 + size
        switch text.align {
        case "right": return (box.x - extra, box.width + extra)
        case "center": return (box.x - extra / 2, box.width + extra)
        default: return (box.x, box.width + extra)
        }
    }

    static func paragraph(runs: [ExportLayout.Run], text: ExportLayout.TextBox, scale: PptxScale) -> String {
        let align = ["center": "ctr", "right": "r", "justify": "just"][text.align] ?? "l"
        let spacing = min(158_400, max(0, scale.centipoints(text.lineHeight)))
        let body = runs.map { run($0, scale: scale) }.joined()
        let end = runs.last.map { properties($0, scale: scale, tag: "a:endParaRPr") } ?? ""
        return "<a:p><a:pPr algn=\"\(align)\"><a:lnSpc><a:spcPts val=\"\(spacing)\"/></a:lnSpc></a:pPr>\(body)\(end)</a:p>"
    }

    static func run(_ run: ExportLayout.Run, scale: PptxScale) -> String {
        "<a:r>\(properties(run, scale: scale, tag: "a:rPr"))<a:t>\(XMLText.escape(run.text))</a:t></a:r>"
    }

    static func properties(_ run: ExportLayout.Run, scale: PptxScale, tag: String) -> String {
        let size = min(400_000, max(100, scale.centipoints(run.size)))
        var attributes = "lang=\"en-US\" sz=\"\(size)\""
        if run.weight >= 600 { attributes += " b=\"1\"" }
        if run.italic { attributes += " i=\"1\"" }
        if run.underline { attributes += " u=\"sng\"" }
        let spacing = scale.centipoints(run.letterSpacing)
        if spacing != 0 { attributes += " spc=\"\(max(-400_000, min(400_000, spacing)))\"" }
        attributes += " dirty=\"0\""
        let family = XMLText.escape(fontFamily(run.family))
        // pitchFamily tells apps without the font what to substitute: 34 sans-serif, 18 serif, 49 monospaced.
        let pitch = ["serif": 18, "monospace": 49][run.generic ?? ""] ?? 34
        let face = "typeface=\"\(family)\" pitchFamily=\"\(pitch)\" charset=\"0\""
        return "<\(tag) \(attributes)>\(fill(run.color))<a:latin \(face)/><a:cs \(face)/></\(tag)>"
    }

    /// `rgb(…)` / `rgba(…)` as a solid fill with alpha.
    static func fill(_ css: String) -> String {
        guard let colour = CSSColour(css) else { return "" }
        let alpha = colour.alpha < 1 ? "<a:alpha val=\"\(Int((colour.alpha * 100_000).rounded()))\"/>" : ""
        return "<a:solidFill><a:srgbClr val=\"\(colour.hex)\">\(alpha)</a:srgbClr></a:solidFill>"
    }

    /// CSS generic families have no PowerPoint equivalent; use common fonts.
    static func fontFamily(_ css: String) -> String {
        switch css.lowercased() {
        case "system-ui", "-apple-system", "blinkmacsystemfont", "ui-sans-serif", "sans-serif", "":
            return "Helvetica Neue"
        case "ui-monospace", "monospace", "sfmono-regular", "ui-monospace sfmono-regular": return "Menlo"
        case "ui-serif", "serif": return "Georgia"
        default: return css
        }
    }
}

/// A computed CSS colour.
struct CSSColour: Equatable {
    let red, green, blue: Int
    let alpha: Double

    init?(_ css: String) {
        let numbers = css.split { !"0123456789.".contains($0) }.compactMap { Double($0) }
        guard css.hasPrefix("rgb"), numbers.count >= 3 else { return nil }
        red = Int(numbers[0].rounded())
        green = Int(numbers[1].rounded())
        blue = Int(numbers[2].rounded())
        alpha = numbers.count >= 4 ? min(1, max(0, numbers[3])) : 1
    }

    var hex: String { String(format: "%02X%02X%02X", red, green, blue) }
}
