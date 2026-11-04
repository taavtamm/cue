import Foundation

/// DrawingML fills as CSS `background` values.
enum PptxFill {
    /// The fill set directly in `spPr`/`bgPr`, else the theme style `fillRef`.
    /// `nil` means no fill was specified at all.
    static func background(in properties: XNode?, styleRef: XNode? = nil, _ context: PptxContext) -> String? {
        if let properties, let fill = fillNode(in: properties) { return background(of: fill, context) }
        if let styleRef, let fill = themeFill(styleRef, list: context.theme.fillStyles, context) { return fill }
        return nil
    }

    /// `bgRef idx="1001…"` picks from the theme's background fill list.
    static func themeFill(_ ref: XNode, list: [XNode], _ context: PptxContext) -> String? {
        guard let raw = ref.int("idx"), raw > 0 else { return nil }
        let index = raw >= 1001 ? raw - 1001 : raw - 1
        let styles = raw >= 1001 ? context.theme.backgroundFillStyles : list
        guard styles.indices.contains(index) else { return nil }
        var tinted = context
        tinted.colors.placeholder = context.colors.color(in: ref)
        return background(of: styles[index], tinted)
    }

    static func fillNode(in properties: XNode) -> XNode? {
        properties.children.first { ["solidFill", "gradFill", "blipFill", "noFill", "pattFill", "grpFill"].contains($0.name) }
    }

    static func background(of fill: XNode, _ context: PptxContext) -> String? {
        switch fill.name {
        case "noFill": return "transparent"
        case "solidFill": return context.colors.color(in: fill)?.css
        case "gradFill": return gradient(fill, context)
        case "blipFill":
            guard let url = context.asset(relationship: fill.child("blip")?["embed"]) else { return nil }
            let size = fill.child("tile") != nil ? "auto" : "100% 100%"
            let repeatMode = fill.child("tile") != nil ? "repeat" : "no-repeat"
            return "url(\"\(url)\") center / \(size) \(repeatMode)"
        case "pattFill":
            context.note("Pattern fills are shown as a solid colour")
            return context.colors.color(in: fill.child("fgClr"))?.css
        default: return nil
        }
    }

    /// Linear gradients use `lin ang` (0° = left to right, clockwise);
    /// path gradients become radial.
    static func gradient(_ fill: XNode, _ context: PptxContext) -> String? {
        let stops = (fill.child("gsLst")?.children("gs") ?? []).compactMap { stop -> (Double, String)? in
            guard let color = context.colors.color(in: stop) else { return nil }
            return ((stop.double("pos") ?? 0) / 1000, color.css)
        }.sorted { $0.0 < $1.0 }
        guard !stops.isEmpty else { return nil }
        let list = stops.map { "\($0.1) \(css($0.0, "%"))" }.joined(separator: ", ")
        if let path = fill.child("path") {
            let shape = path["path"] == "circle" ? "circle" : "ellipse"
            return "radial-gradient(\(shape) at center, \(list))"
        }
        let angle = (fill.child("lin")?.double("ang") ?? 0) / 60_000 + 90
        return "linear-gradient(\(css(angle, "deg")), \(list))"
    }
}
