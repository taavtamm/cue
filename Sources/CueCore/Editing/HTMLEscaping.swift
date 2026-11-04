import Foundation

/// Escapes text for the place it goes in HTML. Characters the file's
/// encoding can't store become numeric references (`&#x2014;`), which HTML
/// reads back as the same character, so nothing is lost or corrupted.
struct HTMLEscaping {
    let encoding: String.Encoding

    /// Element content: `&` and `<` must be escaped.
    func text(_ value: String) -> String {
        escape(value) { character in
            switch character {
            case "&": "&amp;"
            case "<": "&lt;"
            case ">": "&gt;"
            default: nil
            }
        }
    }

    /// An attribute value inside `quote`.
    func attribute(_ value: String, quote: Character = "\"") -> String {
        escape(value) { character in
            switch character {
            case "&": "&amp;"
            case "\"" where quote == "\"": "&quot;"
            case "'" where quote == "'": "&#39;"
            case "<": "&lt;"
            default: nil
            }
        }
    }

    /// Code contexts (CSS, JSON) have no HTML escapes: refuse what won't encode.
    func verbatim(_ value: String) throws -> String {
        for character in value where !fits(character) { throw EditError.unencodable(character) }
        return value
    }

    private func escape(_ value: String, _ special: (Character) -> String?) -> String {
        var result = ""
        for character in value {
            if let replacement = special(character) {
                result += replacement
            } else if fits(character) {
                result.append(character)
            } else {
                for scalar in character.unicodeScalars {
                    result += "&#x\(String(scalar.value, radix: 16, uppercase: true));"
                }
            }
        }
        return result
    }

    private func fits(_ character: Character) -> Bool {
        switch encoding {
        case .utf8, .utf16, .utf16BigEndian, .utf16LittleEndian, .utf32, .unicode: true
        default: String(character).canBeConverted(to: encoding)
        }
    }

    /// Valid HTML attribute names for attributes Cue writes.
    static func isValidAttributeName(_ name: String) -> Bool {
        !name.isEmpty && name.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar) && !"\"'>/=<`".unicodeScalars.contains(scalar)
                && scalar.value > 0x1F
        }
    }
}
