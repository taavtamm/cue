import Foundation

/// Maps key names to show actions. Kept as data so the app (and later, user
/// settings) can feed it without CueCore knowing about AppKit.
///
/// Key names: single characters ("b", "1", " ") as typed, plus the special
/// names below for keys without a character.
public struct ShowKeyMap: Sendable {
    public enum Name {
        public static let right = "ArrowRight"
        public static let left = "ArrowLeft"
        public static let down = "ArrowDown"
        public static let up = "ArrowUp"
        public static let pageDown = "PageDown"
        public static let pageUp = "PageUp"
        public static let home = "Home"
        public static let end = "End"
        public static let space = " "
        public static let shiftSpace = "Shift+ "
        public static let returnKey = "Return"
        public static let escape = "Escape"
    }

    public var bindings: [String: ShowKey]

    public init(bindings: [String: ShowKey]) {
        self.bindings = bindings
    }

    /// Arrows, space, Page Up/Down (what presentation clickers send), B, W,
    /// Esc, Home/End and number + Return.
    public static let standard: ShowKeyMap = {
        var bindings: [String: ShowKey] = [
            Name.right: .next, Name.down: .next, Name.pageDown: .next, Name.space: .next,
            Name.left: .previous, Name.up: .previous, Name.pageUp: .previous, Name.shiftSpace: .previous,
            Name.home: .first, Name.end: .last,
            "b": .toggleBlack, "B": .toggleBlack, ".": .toggleBlack,
            "w": .toggleWhite, "W": .toggleWhite,
            Name.returnKey: .confirm, Name.escape: .endShow,
        ]
        for digit in 0...9 { bindings[String(digit)] = .digit(digit) }
        return ShowKeyMap(bindings: bindings)
    }()

    public func action(for keyName: String) -> ShowKey? { bindings[keyName] }
}
