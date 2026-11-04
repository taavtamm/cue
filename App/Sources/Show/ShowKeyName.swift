import AppKit
import CueCore

/// Turns an AppKit key event into a `ShowKeyMap` key name.
enum ShowKeyName {
    private static let special: [UInt16: String] = [
        124: ShowKeyMap.Name.right, 123: ShowKeyMap.Name.left,
        125: ShowKeyMap.Name.down, 126: ShowKeyMap.Name.up,
        121: ShowKeyMap.Name.pageDown, 116: ShowKeyMap.Name.pageUp,
        115: ShowKeyMap.Name.home, 119: ShowKeyMap.Name.end,
        36: ShowKeyMap.Name.returnKey, 76: ShowKeyMap.Name.returnKey,
        53: ShowKeyMap.Name.escape,
    ]

    /// Nil for ⌘/⌃/⌥ combinations, so menu shortcuts like ⌘Q keep working.
    static func name(for event: NSEvent) -> String? {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option])
        guard modifiers.isEmpty else { return nil }
        if let name = special[event.keyCode] { return name }
        guard let characters = event.charactersIgnoringModifiers, characters.count == 1 else { return nil }
        if characters == " " && event.modifierFlags.contains(.shift) { return ShowKeyMap.Name.shiftSpace }
        return characters
    }
}
