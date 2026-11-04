import Foundation

/// `custGeom` outlines (logos, icons) as inline SVG paths.
enum PptxCustomGeometry {
    /// Nil when the geometry has nothing drawable.
    static func svg(_ geometry: XNode, fill: String?, line: PptxLine?, _ context: PptxContext) -> String? {
        let paths = geometry.child("pathLst")?.children("path") ?? []
        var out = ""
        for path in paths {
            let w = path.double("w") ?? 1, h = path.double("h") ?? 1
            guard let d = pathData(path, context) else { continue }
            let noFill = path["fill"] == "none"
            let fillValue = noFill ? "none" : solid(fill) ?? "none"
            let stroke = path["stroke"] == "0" ? nil : line?.color
            let strokeAttributes = stroke.map {
                " stroke=\"\($0)\" stroke-width=\"\(css(max(line?.width ?? 1, 0.5), ""))\" vector-effect=\"non-scaling-stroke\""
            } ?? ""
            out += "<svg width=\"100%\" height=\"100%\" viewBox=\"0 0 \(css(w, "")) \(css(h, ""))\" "
                + "preserveAspectRatio=\"none\" style=\"position: absolute; inset: 0; overflow: visible\">"
                + "<path d=\"\(d)\" fill=\"\(fillValue)\"\(strokeAttributes)/></svg>"
        }
        return out.isEmpty ? nil : out
    }

    /// Gradients and pictures don't carry into a path fill; use their first colour.
    private static func solid(_ fill: String?) -> String? {
        guard let fill else { return nil }
        if fill.hasPrefix("#") || fill.hasPrefix("rgba") || fill == "transparent" { return fill }
        if let range = fill.range(of: #"(#[0-9a-f]{6}|rgba\([^)]*\))"#, options: .regularExpression) {
            return String(fill[range])
        }
        return nil
    }

    private static func pathData(_ path: XNode, _ context: PptxContext) -> String? {
        var parts: [String] = []
        func point(_ node: XNode?) -> String {
            "\(css(node?.double("x") ?? 0, "")) \(css(node?.double("y") ?? 0, ""))"
        }
        for command in path.children {
            let points = command.children("pt")
            switch command.name {
            case "moveTo": parts.append("M" + point(points.first))
            case "lnTo": parts.append("L" + point(points.first))
            case "cubicBezTo" where points.count == 3: parts.append("C" + points.map(point).joined(separator: " "))
            case "quadBezTo" where points.count == 2: parts.append("Q" + points.map(point).joined(separator: " "))
            case "close": parts.append("Z")
            case "arcTo": context.note("Curved arcs in custom shapes are drawn straight")
            default: continue
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
