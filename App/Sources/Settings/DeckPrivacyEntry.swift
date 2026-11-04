import AppKit
import CueCore

/// One recent deck's network and device choices, read from and written
/// back to its `deck.cue.json` sidecar.
struct DeckPrivacyEntry: Identifiable, Equatable {
    let deck: URL
    var sidecar: CueSidecar

    var id: URL { deck }
    var name: String { deck.deletingPathExtension().lastPathComponent }

    /// Decks with something to show: an allowed or refused host, or a device permission.
    static func load(for decks: [URL]) -> [DeckPrivacyEntry] {
        decks.compactMap { deck in
            let url = CueSidecar.url(forDeck: deck)
            guard let sidecar = try? CueSidecar.load(from: url) else { return nil }
            let hasChoices = !sidecar.allowedHosts.isEmpty || !sidecar.deniedHosts.isEmpty
                || sidecar.permissions != .none
            return hasChoices ? DeckPrivacyEntry(deck: deck, sidecar: sidecar) : nil
        }
    }

    /// Applies `change` to the sidecar on disk, keeping every other field
    /// (display roles, rehearsal timings) as it is there.
    mutating func update(_ change: (inout CueSidecar) -> Void) throws {
        let url = CueSidecar.url(forDeck: deck)
        try CueSidecar.update(at: url, change)
        sidecar = try CueSidecar.load(from: url)
    }
}
