import AppKit
import CueCore
import CueEditor
import Observation

/// Warns when the deck keeps the GPU busy (measured as slides play in the
/// editor) and hands the user a prompt for their AI to make it lighter.
/// Cue can't start that conversation itself: it never signs in to Claude.
@MainActor @Observable
final class DeckPerformanceWarning {
    private let session: EditorSession
    private let sidecarURL: URL
    /// "Not now" lasts until the deck is closed; Never is saved with the deck.
    private var postponed = false
    private var never: Bool
    /// The prompt was just copied: the banner says so.
    private(set) var copied = false

    init(session: EditorSession) {
        self.session = session
        sidecarURL = session.document.sidecarURL
        never = (try? CueSidecar.load(from: sidecarURL))?.hidesPerformanceWarning ?? false
    }

    var report: DeckLoadReport { DeckLoadReport(session.loads) }
    var isShown: Bool { !postponed && !never && report.isHeavy }

    func copyPrompt() {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(report.prompt(deckTitle: session.title), forType: .string)
        copied = true
    }

    func notNow() { postponed = true }

    func neverForThisDeck() {
        never = true
        try? CueSidecar.update(at: sidecarURL) { $0.hidesPerformanceWarning = true }
    }
}
