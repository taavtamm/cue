import Foundation

/// A show action, independent of keyboards. The app turns key presses into
/// these through `ShowKeyMap`; clickers send the same keys as a keyboard.
public enum ShowKey: Sendable, Equatable, Hashable {
    case next
    case previous
    case first
    case last
    case toggleBlack
    case toggleWhite
    /// A typed digit, part of "number then Return" jumping.
    case digit(Int)
    /// Return: jump to the typed number, if any.
    case confirm
    case endShow
}
