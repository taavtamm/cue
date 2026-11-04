import Foundation

/// An ordered list of CSS declarations, written as an inline `style`.
public struct CSSStyle: Sendable, Equatable {
    public private(set) var declarations: [(String, String)] = []

    public init() {}

    public static func == (lhs: CSSStyle, rhs: CSSStyle) -> Bool { lhs.text == rhs.text }

    /// Sets a property, replacing an earlier value.
    public mutating func set(_ property: String, _ value: String?) {
        declarations.removeAll { $0.0 == property }
        if let value, !value.isEmpty { declarations.append((property, value)) }
    }

    public subscript(_ property: String) -> String? {
        declarations.last { $0.0 == property }?.1
    }

    public var text: String {
        declarations.map { "\($0.0): \($0.1)" }.joined(separator: "; ")
    }

    public var isEmpty: Bool { declarations.isEmpty }
}

/// Number formatting for CSS: at most two decimals, no trailing zeros.
public func css(_ value: Double, _ unit: String = "px") -> String {
    let rounded = (value * 100).rounded() / 100
    let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    return text + (rounded == 0 ? "" : unit)
}
