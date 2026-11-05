import CueCore
import CueMCP
import Foundation

/// The deck tools, run on the main actor where Cue's windows live.
extension MCPHostController {
    func decks() async -> [DeckSummary] { await MainActor.run { ClaudeDecks.summaries() } }

    func createDeck(at url: URL, title: String, html: String?) async throws -> DeckSummary {
        try await MainActor.run { try ClaudeDecks.create(at: url, title: title, html: html) }
    }

    func openDeck(_ url: URL) async throws -> DeckSummary { try await ClaudeDecks.open(url) }

    func saveDeck() async throws -> DeckSummary { try await MainActor.run { try ClaudeDecks.save() } }

    func newDeckFolder() async -> URL {
        await MainActor.run { NewDeckLocation.defaultFolder(saveFolder: CueSettings.shared.defaultSaveFolder) }
    }
}
