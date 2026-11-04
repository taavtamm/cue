import Foundation

/// Where an element's value for one CSS property comes from, so the
/// inspector can say "from deck stylesheet" and edit the right place.
public struct StyleProvenance: Sendable, Equatable {
    public enum Origin: String, Sendable {
        /// The element's `style` attribute.
        case inline
        /// Cue's `<style id="cue-overrides">` block.
        case cueOverrides
        /// A rule in the deck's own stylesheets. Cue never edits these.
        case stylesheet
        /// Not set on the element; an ancestor's value carries over.
        case inherited
        /// The browser's default.
        case `default`
    }

    public let property: String
    public let origin: Origin
    /// The declared value at the origin, e.g. `var(--ink)`.
    public let value: String
    /// The resolved value, e.g. `rgb(20, 20, 20)`.
    public let computed: String
    /// The winning rule's selector, for `.stylesheet` and `.cueOverrides`.
    public let selector: String?
    public let sheetIndex: Int?
    /// `<style>`, `<style id="…">` or a linked sheet's href.
    public let sheet: String?
    /// For `.inherited`: the cue-id of the parent it came from.
    public let inheritedFrom: String?
    /// Cross-origin sheets the cascade couldn't read.
    public let unreadableSheets: Int

    init?(_ object: Any?) {
        guard let values = object as? [String: Any],
              let origin = (values["origin"] as? String).flatMap(Origin.init(rawValue:))
        else { return nil }
        self.origin = origin
        property = values["property"] as? String ?? ""
        value = values["value"] as? String ?? ""
        computed = values["computed"] as? String ?? ""
        selector = values["selector"] as? String
        sheetIndex = values["sheetIndex"] as? Int
        sheet = values["sheet"] as? String
        inheritedFrom = values["from"] as? String
        unreadableSheets = values["unreadableSheets"] as? Int ?? 0
    }

    /// Short text for the inspector, e.g. "from deck stylesheet · .headline".
    public var summary: String {
        switch origin {
        case .inline: "inline style"
        case .cueOverrides: "Cue override · \(selector ?? "")"
        case .stylesheet: "from deck stylesheet · \(selector ?? "")"
        case .inherited: "inherited"
        case .default: "browser default"
        }
    }
}
