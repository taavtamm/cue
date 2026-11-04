import AppKit
import UniformTypeIdentifiers

/// The Open panel and open-failure alerts.
@MainActor
enum DeckOpener {
    static func chooseDecks(_ completion: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Open a presentation"
        panel.allowedContentTypes = [.html]
        panel.allowsMultipleSelection = true
        panel.begin { response in
            completion(response == .OK ? panel.urls : [])
        }
    }

    static func reportFailure(opening url: URL, error: any Error) {
        let alert = NSAlert()
        alert.messageText = "Cue couldn't open “\(url.lastPathComponent)”."
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
