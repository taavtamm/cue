import Foundation

/// The parts of a theme the converter uses: colours, fonts and style lists.
struct PptxTheme {
    var colors: [String: RGBA] = [:]
    var majorLatin = "Calibri Light"
    var minorLatin = "Calibri"
    var fillStyles: [XNode] = []
    var lineStyles: [XNode] = []
    var backgroundFillStyles: [XNode] = []

    init() {}

    init(_ root: XNode) {
        let elements = root.child("themeElements")
        if let scheme = elements?.child("clrScheme") {
            let resolver = PptxColors(scheme: [:], map: [:])
            for entry in scheme.children {
                if let color = resolver.color(in: entry) { colors[entry.name] = color }
            }
        }
        if let fonts = elements?.child("fontScheme") {
            majorLatin = fonts.at("majorFont", "latin")?["typeface"] ?? majorLatin
            minorLatin = fonts.at("minorFont", "latin")?["typeface"] ?? minorLatin
        }
        let formats = elements?.child("fmtScheme")
        fillStyles = formats?.child("fillStyleLst")?.children ?? []
        lineStyles = formats?.child("lnStyleLst")?.children ?? []
        backgroundFillStyles = formats?.child("bgFillStyleLst")?.children ?? []
    }

    /// `+mj-lt` / `+mn-lt` theme font references, or the typeface itself.
    func typeface(_ name: String?) -> String? {
        switch name {
        case "+mj-lt", "+mj-ea", "+mj-cs": majorLatin
        case "+mn-lt", "+mn-ea", "+mn-cs": minorLatin
        default: name
        }
    }
}
