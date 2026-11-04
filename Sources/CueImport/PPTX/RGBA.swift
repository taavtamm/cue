import Foundation

/// A colour with components in 0…1, written as CSS.
struct RGBA: Equatable {
    var red, green, blue, alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clamped01
        self.green = green.clamped01
        self.blue = blue.clamped01
        self.alpha = alpha.clamped01
    }

    /// `"1F4E79"` → colour. Invalid text gives nil.
    init?(hex: String) {
        let clean = hex.trimmingCharacters(in: .whitespaces)
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var css: String {
        let r = Int((red * 255).rounded()), g = Int((green * 255).rounded()), b = Int((blue * 255).rounded())
        if alpha >= 0.999 { return String(format: "#%02x%02x%02x", r, g, b) }
        return "rgba(\(r), \(g), \(b), \((alpha * 1000).rounded() / 1000))"
    }

    // MARK: HSL, for DrawingML's lumMod / lumOff / satMod

    var hsl: (h: Double, s: Double, l: Double) {
        let maxC = max(red, green, blue), minC = min(red, green, blue)
        let l = (maxC + minC) / 2
        guard maxC != minC else { return (0, 0, l) }
        let d = maxC - minC
        let s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        var h: Double
        switch maxC {
        case red: h = (green - blue) / d + (green < blue ? 6 : 0)
        case green: h = (blue - red) / d + 2
        default: h = (red - green) / d + 4
        }
        h /= 6
        return (h, s, l)
    }

    init(h: Double, s: Double, l: Double, alpha: Double) {
        guard s > 0 else {
            self.init(red: l, green: l, blue: l, alpha: alpha)
            return
        }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1 / 6 { return p + (q - p) * 6 * t }
            if t < 1 / 2 { return q }
            if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
            return p
        }
        self.init(red: channel(h + 1 / 3), green: channel(h), blue: channel(h - 1 / 3), alpha: alpha)
    }
}

extension Double {
    var clamped01: Double { Swift.min(1, Swift.max(0, self)) }
}
