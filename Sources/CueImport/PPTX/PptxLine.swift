import Foundation

/// An outline: width in px, CSS colour and dash style. Nil colour = none.
struct PptxLine: Equatable {
    var width: Double
    var color: String?
    var dash: String

    var cssBorder: String? {
        guard let color, width > 0 else { return nil }
        return "\(css(max(width, 0.5))) \(dash) \(color)"
    }

    /// `spPr/ln`, else the theme line style from `p:style/lnRef`.
    static func from(_ properties: XNode?, styleRef: XNode?, _ context: PptxContext) -> PptxLine? {
        var themeLine: XNode?
        var tinted = context
        if let styleRef, let index = styleRef.int("idx"), index > 0, context.theme.lineStyles.indices.contains(index - 1) {
            themeLine = context.theme.lineStyles[index - 1]
            tinted.colors.placeholder = context.colors.color(in: styleRef)
        }
        let direct = properties?.child("ln")
        guard direct != nil || themeLine != nil else { return nil }
        if direct?.child("noFill") != nil { return PptxLine(width: 0, color: nil, dash: "solid") }

        let widthEMU = direct?.double("w") ?? themeLine?.double("w") ?? 9525
        var color = direct.flatMap { context.colors.color(in: $0.child("solidFill")) }
        if color == nil, direct?.child("solidFill") == nil, let themeLine, themeLine.child("noFill") == nil {
            color = tinted.colors.color(in: themeLine.child("solidFill"))
        }
        let dashName = direct?.child("prstDash")?["val"] ?? themeLine?.child("prstDash")?["val"] ?? "solid"
        let dash = dashName.contains("Dot") || dashName == "dot" ? "dotted" : (dashName == "solid" ? "solid" : "dashed")
        return PptxLine(width: widthEMU / PptxUnits.emuPerPixel, color: color?.css, dash: dash)
    }
}
