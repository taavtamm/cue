import Foundation

/// Bullet characters and automatic numbers.
enum PptxBullets {
    /// Symbol fonts store bullets as letters; map the common ones to Unicode.
    static func character(_ raw: String, font: String?) -> String {
        let face = (font ?? "").lowercased()
        if face.hasPrefix("wingdings") {
            let map: [String: String] = ["§": "▪", "Ø": "➢", "ü": "✓", "q": "❑", "v": "❖", "l": "●", "n": "■",
                                         "Ü": "✓", "ª": "▫", "o": "□", "p": "◆"]
            return map[raw] ?? "•"
        }
        if face == "symbol" { return raw == "·" ? "•" : raw }
        return raw
    }

    /// `arabicPeriod` 3 → "3.", `alphaLcParenR` 2 → "b)", `romanUcPeriod` 4 → "IV."
    static func number(_ value: Int, scheme: String) -> String {
        let body: String
        if scheme.hasPrefix("alphaLc") {
            body = letters(value).lowercased()
        } else if scheme.hasPrefix("alphaUc") {
            body = letters(value)
        } else if scheme.hasPrefix("romanLc") {
            body = roman(value).lowercased()
        } else if scheme.hasPrefix("romanUc") {
            body = roman(value)
        } else {
            body = String(value)
        }
        if scheme.hasSuffix("ParenBoth") { return "(\(body))" }
        if scheme.hasSuffix("ParenR") { return "\(body))" }
        if scheme.hasSuffix("Plain") { return body }
        return "\(body)."
    }

    private static func letters(_ value: Int) -> String {
        var n = max(1, value), out = ""
        while n > 0 {
            n -= 1
            out = String(UnicodeScalar(UInt8(65 + n % 26))) + out
            n /= 26
        }
        return out
    }

    private static func roman(_ value: Int) -> String {
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = max(1, value), out = ""
        for (number, symbol) in table {
            while n >= number {
                out += symbol
                n -= number
            }
        }
        return out
    }
}
