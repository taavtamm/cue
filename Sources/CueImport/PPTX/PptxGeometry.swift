import Foundation

/// Preset shapes. Common ones map to CSS (radius, clip-path); lines become
/// SVG; anything else is drawn as its bounding rectangle and reported.
enum PptxGeometry {
    enum Shape {
        case box(radius: String?, clipPath: String?)
        case line
        case unknown(String)
    }

    static func shape(_ properties: XNode?, frame: Rect) -> Shape {
        guard let geometry = properties?.child("prstGeom") else { return .box(radius: nil, clipPath: nil) }
        let name = geometry["prst"] ?? "rect"
        let adjust = adjustments(geometry)
        let short = min(frame.width, frame.height)
        switch name {
        case "rect", "flowChartProcess", "snip1Rect": return .box(radius: nil, clipPath: nil)
        case "roundRect", "flowChartAlternateProcess":
            return .box(radius: css((adjust["adj"] ?? 16_667) / 100_000 * short), clipPath: nil)
        case "ellipse", "flowChartConnector": return .box(radius: "50%", clipPath: nil)
        case "line", "straightConnector1", "bentConnector2", "bentConnector3", "curvedConnector3": return .line
        default:
            if let polygon = polygons[name] { return .box(radius: nil, clipPath: "polygon(\(polygon))") }
            return .unknown(name)
        }
    }

    private static func adjustments(_ geometry: XNode) -> [String: Double] {
        var values: [String: Double] = [:]
        for guide in geometry.child("avLst")?.children("gd") ?? [] {
            guard let name = guide["name"], let formula = guide["fmla"], formula.hasPrefix("val ") else { continue }
            values[name] = Double(formula.dropFirst(4))
        }
        return values
    }

    /// Default-adjusted outlines for common presets, as CSS polygon points.
    static let polygons: [String: String] = [
        "triangle": "50% 0, 100% 100%, 0 100%",
        "rtTriangle": "0 0, 100% 100%, 0 100%",
        "diamond": "50% 0, 100% 50%, 50% 100%, 0 50%",
        "parallelogram": "25% 0, 100% 0, 75% 100%, 0 100%",
        "trapezoid": "25% 0, 75% 0, 100% 100%, 0 100%",
        "pentagon": "50% 0, 100% 38%, 82% 100%, 18% 100%, 0 38%",
        "hexagon": "25% 0, 75% 0, 100% 50%, 75% 100%, 25% 100%, 0 50%",
        "octagon": "29% 0, 71% 0, 100% 29%, 100% 71%, 71% 100%, 29% 100%, 0 71%, 0 29%",
        "homePlate": "0 0, 80% 0, 100% 50%, 80% 100%, 0 100%",
        "chevron": "0 0, 80% 0, 100% 50%, 80% 100%, 0 100%, 20% 50%",
        "rightArrow": "0 25%, 70% 25%, 70% 0, 100% 50%, 70% 100%, 70% 75%, 0 75%",
        "leftArrow": "30% 0, 30% 25%, 100% 25%, 100% 75%, 30% 75%, 30% 100%, 0 50%",
        "upArrow": "50% 0, 100% 30%, 75% 30%, 75% 100%, 25% 100%, 25% 30%, 0 30%",
        "downArrow": "25% 0, 75% 0, 75% 70%, 100% 70%, 50% 100%, 0 70%, 25% 70%",
        "plus": "33% 0, 67% 0, 67% 33%, 100% 33%, 100% 67%, 67% 67%, 67% 100%, 33% 100%, 33% 67%, 0 67%, 0 33%, 33% 33%",
        "star5": "50% 0, 61% 35%, 98% 35%, 68% 57%, 79% 91%, 50% 70%, 21% 91%, 32% 57%, 2% 35%, 39% 35%",
    ]

    /// A connector drawn corner to corner of its box, honouring flips.
    static func lineSVG(frame: Rect, flipH: Bool, flipV: Bool, line: PptxLine?, arrowAtEnd: Bool) -> String {
        let w = max(frame.width, 1), h = max(frame.height, 1)
        let x1 = flipH ? w : 0, x2 = flipH ? 0 : w
        let y1 = flipV ? h : 0, y2 = flipV ? 0 : h
        let color = line?.color ?? "#000"
        let width = max(line?.width ?? 1, 0.75)
        var marker = "", markerRef = ""
        if arrowAtEnd {
            marker = "<defs><marker id=\"a\" viewBox=\"0 0 10 10\" refX=\"8\" refY=\"5\" markerWidth=\"5\" markerHeight=\"5\" "
                + "orient=\"auto\"><path d=\"M0 0L10 5L0 10z\" fill=\"\(color)\"/></marker></defs>"
            markerRef = " marker-end=\"url(#a)\""
        }
        let dash = line?.dash == "dashed" ? " stroke-dasharray=\"\(css(width * 4, ""))\"" : ""
        return "<svg width=\"100%\" height=\"100%\" viewBox=\"0 0 \(css(w, "")) \(css(h, ""))\" "
            + "preserveAspectRatio=\"none\" style=\"overflow: visible\">\(marker)"
            + "<line x1=\"\(css(x1, ""))\" y1=\"\(css(y1, ""))\" x2=\"\(css(x2, ""))\" y2=\"\(css(y2, ""))\" "
            + "stroke=\"\(color)\" stroke-width=\"\(css(width, ""))\"\(dash)\(markerRef)/></svg>"
    }
}
