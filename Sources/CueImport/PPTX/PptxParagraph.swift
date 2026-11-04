import Foundation

/// One `a:p` with its resolved properties, rendered to HTML.
struct PptxParagraph {
    let node: XNode
    let props: PptxParagraphProperties
    let scale: Double
    let lineReduction: Double
    let context: PptxContext

    static let defaultSize = 1800.0

    var isNumbered: Bool {
        if case .autoNumber = props.bullet, hasText { return true }
        return false
    }

    var numberStart: Int {
        if case .autoNumber(_, let start) = props.bullet { return start }
        return 1
    }

    var plainText: String {
        node.children.map { child -> String in
            switch child.name {
            case "r": child.child("t")?.text ?? ""
            case "fld": fieldText(child)
            case "br": "\n"
            default: ""
            }
        }.joined().replacingOccurrences(of: "\u{000B}", with: "\n")
    }

    private var hasText: Bool { !plainText.trimmingCharacters(in: .whitespaces).isEmpty }

    func html(number: Int?) -> String {
        let endSize = node.child("endParaRPr")?.double("sz")
        let size = (props.run.size ?? endSize ?? Self.defaultSize) * scale
        var style = CSSStyle()
        style.set("font-size", css(PptxUnits.pixels(hundredthsOfPoint: size)))
        style.set("text-align", Self.alignment[props.align ?? "l"] ?? "left")
        if let margin = props.marginLeft, margin != 0 { style.set("padding-left", css(margin / PptxUnits.emuPerPixel)) }
        if let indent = props.indent, indent != 0 { style.set("text-indent", css(indent / PptxUnits.emuPerPixel)) }
        if let percent = props.lineSpacingPercent {
            style.set("line-height", css(percent / 100_000 * 1.2 * (1 - lineReduction), ""))
        } else if let points = props.lineSpacingPoints {
            style.set("line-height", css(PptxUnits.pixels(hundredthsOfPoint: points * scale)))
        } else {
            style.set("line-height", css(1.2 * (1 - lineReduction), ""))
        }
        style.set("margin-top", spacing(props.spaceBefore, size: size))
        style.set("margin-bottom", spacing(props.spaceAfter, size: size))

        var inner = hasText ? bulletHTML(number: number) : ""
        for child in node.children {
            switch child.name {
            case "r": inner += span(child.child("t")?.text ?? "", properties: child.child("rPr"))
            case "fld": inner += span(fieldText(child), properties: child.child("rPr"))
            case "br": inner += "<br>"
            default: continue
            }
        }
        if !hasText { inner += "<br>" }
        return "<p style=\"\(HTMLText.attribute(style.text))\">\(inner)</p>"
    }

    private func spacing(_ value: PptxParagraphProperties.Spacing?, size: Double) -> String? {
        switch value {
        case .percent(let pct)?: pct == 0 ? nil : css(pct / 100_000 * PptxUnits.pixels(hundredthsOfPoint: size))
        case .points(let pts)?: pts == 0 ? nil : css(PptxUnits.pixels(hundredthsOfPoint: pts))
        case nil: nil
        }
    }

    private func fieldText(_ field: XNode) -> String {
        field["type"] == "slidenum" ? String(context.slideNumber) : field.child("t")?.text ?? ""
    }

    private func span(_ raw: String, properties: XNode?) -> String {
        var run = props.run
        run.merge(properties, context.colors, context.theme)
        let text = HTMLText.text(raw).replacingOccurrences(of: "\u{000B}", with: "<br>")
        return "<span style=\"\(HTMLText.attribute(runStyle(run).text))\">\(text)</span>"
    }

    func runStyle(_ run: PptxRunProperties) -> CSSStyle {
        var style = CSSStyle()
        var size = PptxUnits.pixels(hundredthsOfPoint: (run.size ?? Self.defaultSize) * scale)
        if let baseline = run.baseline, baseline != 0 {
            style.set("vertical-align", baseline > 0 ? "super" : "sub")
            size *= 0.7
        }
        style.set("font-size", css(size))
        style.set("font-family", context.fonts.cssFamily(run.typeface ?? context.theme.minorLatin))
        if run.bold == true { style.set("font-weight", "700") }
        if run.italic == true { style.set("font-style", "italic") }
        let decorations = [run.underline == true ? "underline" : nil, run.strike == true ? "line-through" : nil].compactMap { $0 }
        if !decorations.isEmpty { style.set("text-decoration", decorations.joined(separator: " ")) }
        style.set("color", (run.color ?? RGBA(red: 0, green: 0, blue: 0)).css)
        if run.allCaps == true { style.set("text-transform", "uppercase") }
        if let spacing = run.spacing, spacing != 0 { style.set("letter-spacing", css(PptxUnits.pixels(hundredthsOfPoint: spacing))) }
        if let highlight = run.highlight { style.set("background", highlight.css) }
        return style
    }

    /// The bullet sits in the hanging indent, so wrapped lines align with the text.
    private func bulletHTML(number: Int?) -> String {
        let symbol: String
        switch props.bullet {
        case .character(let char)?: symbol = PptxBullets.character(char, font: props.bulletFont)
        case .autoNumber(let scheme, _)?: symbol = PptxBullets.number(number ?? 1, scheme: scheme)
        default: return ""
        }
        var run = props.run
        if let first = node.child("r")?.child("rPr") { run.merge(first, context.colors, context.theme) }
        var style = runStyle(run)
        if let color = props.bulletColor { style.set("color", color.css) }
        if let percent = props.bulletSizePercent, let size = style["font-size"].flatMap({ Double($0.dropLast(2)) }) {
            style.set("font-size", css(size * percent / 100_000))
        }
        style.set("font-weight", nil)
        style.set("display", "inline-block")
        style.set("text-indent", "0")
        let hanging = -(props.indent ?? 0) / PptxUnits.emuPerPixel
        style.set(hanging > 0 ? "min-width" : "margin-right", hanging > 0 ? css(hanging) : "0.4em")
        return "<span style=\"\(HTMLText.attribute(style.text))\">\(HTMLText.text(symbol))</span>"
    }

    static let alignment = ["l": "left", "ctr": "center", "r": "right", "just": "justify", "dist": "justify"]
}
