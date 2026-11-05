import Foundation
import MCP

/// A tool call's arguments, with readable errors for Claude when one is
/// missing or the wrong type.
struct ToolArguments: Sendable {
    let values: [String: Value]

    init(_ values: [String: Value]?) { self.values = values ?? [:] }

    func string(_ key: String) -> String? { values[key]?.stringValue }

    func int(_ key: String) -> Int? {
        if let int = values[key]?.intValue { return int }
        if let double = values[key]?.doubleValue, double.rounded() == double { return Int(double) }
        return nil
    }

    func double(_ key: String) -> Double? { values[key]?.doubleValue ?? values[key]?.intValue.map(Double.init) }

    func object(_ key: String) -> ToolArguments? { values[key]?.objectValue.map(ToolArguments.init) }

    func array(_ key: String) -> [Value]? { values[key]?.arrayValue }

    func requiredString(_ key: String) throws -> String {
        guard let value = string(key) else { throw CueMCPError.invalid("“\(key)” is required and must be text.") }
        return value
    }

    func requiredInt(_ key: String) throws -> Int {
        guard let value = int(key) else { throw CueMCPError.invalid("“\(key)” is required and must be a whole number.") }
        return value
    }

    /// A 1-based slide number from Claude, as a 0-based index into the deck.
    func slideIndex(_ key: String = "slide", in document: DeckDocumentFacts) throws -> Int {
        let number = try requiredInt(key)
        guard (1...max(1, document.slideCount)).contains(number), document.slideCount > 0 else {
            throw CueMCPError.invalid("Slide \(number) doesn't exist: the deck has \(document.slideCount) slides (1–\(document.slideCount)).")
        }
        return number - 1
    }

    /// `{"color": "red", "margin": null}`: values to set, nil to remove.
    func stringMap(_ key: String) throws -> [(String, String?)]? {
        guard let object = values[key]?.objectValue else { return nil }
        return try object.keys.sorted().map { name in
            switch object[name] {
            case .null, nil: return (name, nil)
            case .string(let value): return (name, value)
            case .int(let value): return (name, String(value))
            case .double(let value): return (name, String(value))
            default: throw CueMCPError.invalid("“\(key).\(name)” must be text, or null to remove it.")
            }
        }
    }
}

/// The bits of a deck argument checks need, without passing the document around.
struct DeckDocumentFacts {
    let slideCount: Int
}
