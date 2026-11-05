import CueRender
import Foundation

/// DrawingML colours and fills from computed CSS.
enum PptxFillXML {
    /// `<a:srgbClr>` with alpha (the colour's own times `opacity`), or nil for an unreadable colour.
    static func colour(_ css: String, opacity: Double = 1) -> String? {
        guard let colour = CSSColour(css) else { return nil }
        let alpha = colour.alpha * opacity
        let fade = alpha < 0.999 ? "<a:alpha val=\"\(percent(alpha))\"/>" : ""
        return "<a:srgbClr val=\"\(colour.hex)\">\(fade)</a:srgbClr>"
    }

    /// `<a:solidFill>` or `<a:gradFill>`; `<a:noFill/>` without a fill.
    static func fill(_ fill: ExportLayout.Fill?, opacity: Double = 1) -> String {
        guard let fill else { return "<a:noFill/>" }
        if fill.type == "linear", let stops = fill.stops, stops.count >= 2 {
            let list = stops.compactMap { stop in
                colour(stop.color, opacity: opacity).map {
                    "<a:gs pos=\"\(percent(min(1, max(0, stop.position))))\">\($0)</a:gs>"
                }
            }.joined()
            return "<a:gradFill rotWithShape=\"1\"><a:gsLst>\(list)</a:gsLst>"
                + "<a:lin ang=\"\(angle(css: fill.angle ?? 180))\" scaled=\"0\"/></a:gradFill>"
        }
        guard let css = fill.color, let solid = colour(css, opacity: opacity) else { return "<a:noFill/>" }
        return "<a:solidFill>\(solid)</a:solidFill>"
    }

    /// CSS gradient angles point up at 0° and turn clockwise; DrawingML's
    /// point right at 0°, also clockwise, in 60 000ths of a degree.
    static func angle(css degrees: Double) -> Int {
        let turned = (degrees - 90).truncatingRemainder(dividingBy: 360)
        return Int(((turned < 0 ? turned + 360 : turned) * 60_000).rounded())
    }

    /// The slide's `<p:bg>`.
    static func background(_ fill: ExportLayout.Fill) -> String {
        "<p:bg><p:bgPr>\(self.fill(fill))<a:effectLst/></p:bgPr></p:bg>"
    }

    /// 0…1 as DrawingML's 100 000ths.
    static func percent(_ value: Double) -> Int { Int((value * 100_000).rounded()) }
}
