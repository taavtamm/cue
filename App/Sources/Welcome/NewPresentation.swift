import AppKit
import CueCore
import UniformTypeIdentifiers

/// File › New: asks where to save, then writes a blank Cue deck there.
@MainActor
enum NewPresentation {
    static func create(then open: @escaping (URL) -> Void) {
        let settings = CueSettings.shared
        let panel = NSSavePanel()
        panel.title = "New Presentation"
        panel.nameFieldStringValue = "Untitled Presentation.html"
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        if let folder = settings.defaultSaveFolder { panel.directoryURL = folder }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let html = BlankDeckTemplate.html(
                title: url.deletingPathExtension().lastPathComponent,
                fontFamily: settings.defaultFontFamily,
                subtitleSize: settings.defaultFontSize
            )
            do {
                try html.write(to: url, atomically: true, encoding: .utf8)
                open(url)
            } catch {
                DeckOpener.reportFailure(opening: url, error: error)
            }
        }
    }
}
