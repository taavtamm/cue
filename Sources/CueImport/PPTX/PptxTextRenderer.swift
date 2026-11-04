import Foundation

/// Where a text body's inherited styles come from, lowest priority first:
/// the master's title/body/other style or the presentation default, then
/// the master and layout placeholder list styles, then the shape's own.
struct PptxTextChain {
    var lists: [XNode?] = []
    var bodyProperties: [XNode?] = []
    /// From the shape's `p:style/fontRef`: theme text colour and font.
    var baseColor: RGBA?
    var baseTypeface: String?
}

/// Renders a `txBody` as paragraphs of styled spans.
enum PptxTextRenderer {
    struct Result {
        var html: String
        var box: CSSStyle
        var plainText: String
        var hasText: Bool { !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func render(_ body: XNode, chain: PptxTextChain, _ context: PptxContext) -> Result {
        let bodyLayers = chain.bodyProperties + [body.child("bodyPr")]
        let fit = body.child("bodyPr")?.child("normAutofit")
        let scale = (fit?.double("fontScale") ?? 100_000) / 100_000
        let lineReduction = (fit?.double("lnSpcReduction") ?? 0) / 100_000
        let lists = chain.lists + [body.child("lstStyle")]

        var html = "", lines: [String] = []
        var counters: [Int: Int] = [:]
        for paragraph in body.children("p") {
            let level = paragraph.child("pPr")?.int("lvl") ?? 0
            var props = PptxParagraphProperties()
            props.run.color = chain.baseColor
            props.run.typeface = chain.baseTypeface
            for list in lists { props.merge(PptxParagraphProperties.levelNode(list, level: level), context.colors, context.theme) }
            props.merge(paragraph.child("pPr"), context.colors, context.theme)

            let rendered = PptxParagraph(
                node: paragraph, props: props, scale: scale, lineReduction: lineReduction, context: context
            )
            let number = rendered.isNumbered ? nextNumber(&counters, level: level, start: rendered.numberStart) : nil
            if !rendered.isNumbered { counters[level] = nil }
            html += rendered.html(number: number)
            lines.append(rendered.plainText)
        }
        return Result(html: html, box: boxStyle(bodyLayers, context), plainText: lines.joined(separator: "\n"))
    }

    private static func nextNumber(_ counters: inout [Int: Int], level: Int, start: Int) -> Int {
        let value = counters[level].map { $0 + 1 } ?? start
        counters[level] = value
        for deeper in counters.keys where deeper > level { counters[deeper] = nil }
        return value
    }

    /// Insets, vertical anchoring and wrapping from the inherited `bodyPr`s.
    static func boxStyle(_ layers: [XNode?], _ context: PptxContext) -> CSSStyle {
        func value(_ name: String) -> String? { layers.reversed().compactMap { $0?[name] }.first }
        func inset(_ name: String, _ fallback: Double) -> String {
            css((value(name).flatMap(Double.init) ?? fallback) / PptxUnits.emuPerPixel)
        }
        var style = CSSStyle()
        style.set("padding", [inset("tIns", 45_720), inset("rIns", 91_440), inset("bIns", 45_720), inset("lIns", 91_440)]
            .joined(separator: " "))
        switch value("anchor") {
        case "ctr": style.set("justify-content", "center")
        case "b": style.set("justify-content", "flex-end")
        default: style.set("justify-content", "flex-start")
        }
        if value("wrap") == "none" { style.set("white-space", "nowrap") }
        if let vertical = value("vert"), vertical != "horz" {
            style.set("writing-mode", "vertical-rl")
            context.note("Vertical text is approximated")
        }
        return style
    }
}
