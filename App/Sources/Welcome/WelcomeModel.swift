import AppKit
import CueCore
import Observation

/// What the Welcome window shows: the recent decks and their pictures.
@MainActor @Observable
final class WelcomeModel {
    private(set) var recents: [URL] = []
    let thumbnails = WelcomeThumbnails()

    /// Re-reads File › Open Recent (it changes as decks open).
    func refresh() {
        let latest = RecentDecks.pruned(NSDocumentController.shared.recentDocumentURLs)
        guard latest != recents || recents.isEmpty else { return } // Unchanged: keep drawing what's queued.
        recents = latest
        thumbnails.prepare(recents)
    }
}
