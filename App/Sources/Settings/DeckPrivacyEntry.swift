import AppKit
import CueCore

/// One recent deck's network and device choices, read from and written
/// back to `DeckGrantStore`.
struct DeckPrivacyEntry: Identifiable, Equatable {
    let deck: URL
    var grants: DeckGrants

    var id: URL { deck }
    var name: String { deck.deletingPathExtension().lastPathComponent }

    /// Decks with something to show: an allowed or refused host, or a device permission.
    static func load(for decks: [URL]) -> [DeckPrivacyEntry] {
        decks.compactMap { deck in
            let grants = DeckGrantStore.standard.grants(forDeck: deck)
            return grants.isEmpty ? nil : DeckPrivacyEntry(deck: deck, grants: grants)
        }
    }

    /// Applies `change` to the stored choices, keeping other decks' as they are.
    mutating func update(_ change: (inout DeckGrants) -> Void) throws {
        grants = try DeckGrantStore.standard.update(forDeck: deck, change)
    }
}
