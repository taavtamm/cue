import Foundation

/// `a:tbl` as an HTML table. Cell fills, borders and text come across;
/// named table styles are approximated with light borders.
enum PptxTable {
    static func html(_ table: XNode, _ context: PptxContext) -> String {
        let columns = table.child("tblGrid")?.children("gridCol").compactMap { $0.double("w") } ?? []
        let total = max(columns.reduce(0, +), 1)
        let styled = table.child("tblPr")?.child("tableStyleId") != nil
        if styled { context.note("Table styles are approximated") }

        var out = "<table class=\"cue-table\"><colgroup>"
        for width in columns { out += "<col style=\"width: \(css(width / total * 100, "%"))\">" }
        out += "</colgroup>"
        for row in table.children("tr") {
            let height = (row.double("h") ?? 0) / PptxUnits.emuPerPixel
            out += "<tr style=\"height: \(css(height))\">"
            for cell in row.children("tc") where cell.bool("hMerge") != true && cell.bool("vMerge") != true {
                out += cellHTML(cell, styled: styled, context)
            }
            out += "</tr>"
        }
        return out + "</table>"
    }

    private static func cellHTML(_ cell: XNode, styled: Bool, _ context: PptxContext) -> String {
        let properties = cell.child("tcPr")
        var style = CSSStyle()
        style.set("vertical-align", ["ctr": "middle", "b": "bottom"][properties?["anchor"] ?? ""] ?? "top")
        let inset = { (name: String, fallback: Double) in css((properties?.double(name) ?? fallback) / PptxUnits.emuPerPixel) }
        style.set("padding", [inset("marT", 45_720), inset("marR", 91_440), inset("marB", 45_720), inset("marL", 91_440)]
            .joined(separator: " "))
        if let fill = properties.flatMap({ PptxFill.background(in: $0, context) }), fill != "transparent" { style.set("background", fill) }
        var hasBorder = false
        for (edge, name) in [("top", "lnT"), ("right", "lnR"), ("bottom", "lnB"), ("left", "lnL")] {
            guard let line = properties?.child(name) else { continue }
            let wrapper = XNodeBuilder.wrap(line, as: "ln")
            if let border = PptxLine.from(wrapper, styleRef: nil, context)?.cssBorder {
                style.set("border-\(edge)", border)
                hasBorder = true
            }
        }
        if !hasBorder && styled { style.set("border", "1px solid rgba(0, 0, 0, 0.2)") }

        var span = ""
        if let columns = cell.int("gridSpan"), columns > 1 { span += " colspan=\"\(columns)\"" }
        if let rows = cell.int("rowSpan"), rows > 1 { span += " rowspan=\"\(rows)\"" }
        var text = ""
        if let body = cell.child("txBody") {
            let chain = PptxTextChain(lists: [context.defaultTextStyle])
            text = PptxTextRenderer.render(body, chain: chain, context).html
        }
        return "<td\(span) style=\"\(HTMLText.attribute(style.text))\">\(text)</td>"
    }
}
