import Foundation

/// Errors Cue's tools return to Claude, worded for Claude to act on.
public enum CueMCPError: Error, LocalizedError, Equatable {
    case noDeck
    case notApproved(String)
    case denied(String)
    case invalid(String)
    case deckChanged

    public var errorDescription: String? {
        switch self {
        case .noDeck: "No deck is open in Cue. Ask the user to open one."
        case .notApproved(let client):
            "Waiting for approval in Cue: the user needs to allow “\(client)” to edit decks. Try again in a moment."
        case .denied(let client): "The user doesn't allow “\(client)” to edit decks in Cue (Settings › Claude)."
        case .invalid(let message): message
        case .deckChanged:
            "The deck changed while Cue was working on that call (another edit, or the user switched decks), "
                + "so nothing was changed. Read the deck again and retry."
        }
    }
}
