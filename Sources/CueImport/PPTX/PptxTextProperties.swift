import Foundation

/// Character properties after inheritance. Each layer only overrides what it sets.
struct PptxRunProperties {
    var size: Double?          // hundredths of a point
    var bold: Bool?
    var italic: Bool?
    var underline: Bool?
    var strike: Bool?
    var color: RGBA?
    var typeface: String?
    var baseline: Double?      // thousandths of a percent; 30 000 = superscript
    var allCaps: Bool?
    var spacing: Double?       // hundredths of a point
    var highlight: RGBA?

    mutating func merge(_ node: XNode?, _ colors: PptxColors, _ theme: PptxTheme) {
        guard let node else { return }
        if let value = node.double("sz") { size = value }
        if let value = node.bool("b") { bold = value }
        if let value = node.bool("i") { italic = value }
        if let value = node["u"] { underline = value != "none" }
        if let value = node["strike"] { strike = value != "noStrike" }
        if let value = node.double("baseline") { baseline = value }
        if let value = node["cap"] { allCaps = value == "all" }
        if let value = node.double("spc") { spacing = value }
        if let fill = node.child("solidFill"), let value = colors.color(in: fill) { color = value }
        if node.child("noFill") != nil { color = RGBA(red: 0, green: 0, blue: 0, alpha: 0) }
        if let value = node.child("highlight").flatMap({ colors.color(in: $0) }) { highlight = value }
        if let face = node.child("latin")?["typeface"] { typeface = theme.typeface(face) }
    }
}

/// Paragraph properties after inheritance, including the level's default run.
struct PptxParagraphProperties {
    enum Bullet { case none, character(String), autoNumber(scheme: String, start: Int) }

    var align: String?
    var marginLeft: Double?    // EMU
    var indent: Double?        // EMU
    var lineSpacingPercent: Double?
    var lineSpacingPoints: Double?
    var spaceBefore: Spacing?
    var spaceAfter: Spacing?
    var bullet: Bullet?
    var bulletFont: String?
    var bulletColor: RGBA?
    var bulletSizePercent: Double?
    var run = PptxRunProperties()

    enum Spacing { case percent(Double), points(Double) }

    mutating func merge(_ node: XNode?, _ colors: PptxColors, _ theme: PptxTheme) {
        guard let node else { return }
        if let value = node["algn"] { align = value }
        if let value = node.double("marL") { marginLeft = value }
        if let value = node.double("indent") { indent = value }
        if let spacing = node.child("lnSpc") {
            lineSpacingPercent = spacing.child("spcPct")?.double("val")
            lineSpacingPoints = spacing.child("spcPts")?.double("val")
        }
        if let value = Self.spacing(node.child("spcBef")) { spaceBefore = value }
        if let value = Self.spacing(node.child("spcAft")) { spaceAfter = value }
        if node.child("buNone") != nil { bullet = Bullet.none }
        if let char = node.child("buChar")?["char"] { bullet = .character(char) }
        if let number = node.child("buAutoNum") {
            bullet = .autoNumber(scheme: number["type"] ?? "arabicPeriod", start: number.int("startAt") ?? 1)
        }
        if let font = node.child("buFont")?["typeface"] { bulletFont = font }
        if let color = node.child("buClr").flatMap({ colors.color(in: $0) }) { bulletColor = color }
        if let size = node.child("buSzPct")?.double("val") { bulletSizePercent = size }
        run.merge(node.child("defRPr"), colors, theme)
    }

    private static func spacing(_ node: XNode?) -> Spacing? {
        if let pct = node?.child("spcPct")?.double("val") { return .percent(pct) }
        if let pts = node?.child("spcPts")?.double("val") { return .points(pts) }
        return nil
    }

    /// The paragraph style for `level` (0-based) from a list style (`lstStyle`,
    /// `titleStyle`, `bodyStyle`, `otherStyle`, `defaultTextStyle`).
    static func levelNode(_ list: XNode?, level: Int) -> XNode? {
        list?.child("lvl\(level + 1)pPr")
    }
}
