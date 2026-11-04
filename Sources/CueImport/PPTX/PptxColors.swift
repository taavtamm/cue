import Foundation

/// Resolves DrawingML colours: sRGB, scheme (through the master's colour
/// map), system and preset colours, with lumMod/lumOff/tint/shade/alpha.
struct PptxColors {
    /// Theme colour scheme: dk1, lt1, dk2, lt2, accent1…6, hlink, folHlink.
    var scheme: [String: RGBA]
    /// The master's clrMap: bg1 → lt1, tx1 → dk1, …
    var map: [String: String]
    /// `phClr` inside theme styles: the colour the style reference passes in.
    var placeholder: RGBA?

    static let defaultMap = [
        "bg1": "lt1", "tx1": "dk1", "bg2": "lt2", "tx2": "dk2",
        "accent1": "accent1", "accent2": "accent2", "accent3": "accent3", "accent4": "accent4",
        "accent5": "accent5", "accent6": "accent6", "hlink": "hlink", "folHlink": "folHlink",
    ]

    /// The colour inside a container such as `solidFill` or `buClr`.
    func color(in container: XNode?) -> RGBA? {
        guard let container else { return nil }
        for child in container.children {
            if let color = color(of: child) { return color }
        }
        return nil
    }

    /// A colour element itself: `srgbClr`, `schemeClr`…
    func color(of node: XNode) -> RGBA? {
        var base: RGBA?
        switch node.name {
        case "srgbClr": base = node["val"].flatMap { RGBA(hex: $0) }
        case "schemeClr": base = scheme(node["val"])
        case "sysClr": base = (node["lastClr"]).flatMap { RGBA(hex: $0) } ?? Self.system[node["val"] ?? ""]
        case "prstClr": base = Self.preset[node["val"] ?? ""]
        case "scrgbClr":
            base = RGBA(red: (node.double("r") ?? 0) / 100_000, green: (node.double("g") ?? 0) / 100_000,
                        blue: (node.double("b") ?? 0) / 100_000)
        case "hslClr":
            base = RGBA(h: (node.double("hue") ?? 0) / 21_600_000, s: (node.double("sat") ?? 0) / 100_000,
                        l: (node.double("lum") ?? 0) / 100_000, alpha: 1)
        default: return nil
        }
        return base.map { Self.apply(node.children, to: $0) }
    }

    private func scheme(_ name: String?) -> RGBA? {
        guard let name else { return nil }
        if name == "phClr" { return placeholder }
        let mapped = map[name] ?? Self.defaultMap[name] ?? name
        return scheme[mapped]
    }

    /// Colour transforms, applied in document order.
    static func apply(_ modifiers: [XNode], to color: RGBA) -> RGBA {
        var result = color
        for modifier in modifiers {
            let value = (modifier.double("val") ?? 100_000) / 100_000
            switch modifier.name {
            case "alpha": result.alpha = value.clamped01
            case "alphaMod": result.alpha = (result.alpha * value).clamped01
            case "lumMod", "lumOff", "satMod", "satOff":
                var hsl = result.hsl
                switch modifier.name {
                case "lumMod": hsl.l *= value
                case "lumOff": hsl.l += value
                case "satMod": hsl.s *= value
                default: hsl.s += value
                }
                result = RGBA(h: hsl.h, s: hsl.s.clamped01, l: hsl.l.clamped01, alpha: result.alpha)
            case "tint":
                result = RGBA(red: 1 - (1 - result.red) * value, green: 1 - (1 - result.green) * value,
                              blue: 1 - (1 - result.blue) * value, alpha: result.alpha)
            case "shade":
                result = RGBA(red: result.red * value, green: result.green * value,
                              blue: result.blue * value, alpha: result.alpha)
            default: continue
            }
        }
        return result
    }

    static let system: [String: RGBA] = [
        "windowText": RGBA(red: 0, green: 0, blue: 0), "window": RGBA(red: 1, green: 1, blue: 1),
    ]

    static let preset: [String: RGBA] = [
        "black": RGBA(red: 0, green: 0, blue: 0), "white": RGBA(red: 1, green: 1, blue: 1),
        "red": RGBA(red: 1, green: 0, blue: 0), "green": RGBA(red: 0, green: 0.5, blue: 0),
        "blue": RGBA(red: 0, green: 0, blue: 1), "yellow": RGBA(red: 1, green: 1, blue: 0),
        "gray": RGBA(red: 0.5, green: 0.5, blue: 0.5), "orange": RGBA(red: 1, green: 0.65, blue: 0),
    ]
}
