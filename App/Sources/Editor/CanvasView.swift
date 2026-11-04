import CueEditor
import SwiftUI

/// The real slide with Cue's selection and caret drawn natively above it.
/// The values passed in are what the overlay draws, so SwiftUI updates it
/// whenever the selection, inline edit or embed interaction changes.
struct CanvasView: View {
    let session: EditorSession
    @Environment(\.isSnapshotRendering) private var isSnapshot

    var body: some View {
        // Snapshots lay the slide's own picture over this (see EditorSnapshots).
        if isSnapshot { Color.black } else { CanvasHost(session: session) }
    }
}

private struct CanvasHost: NSViewRepresentable {
    let session: EditorSession

    func makeNSView(context: Context) -> CanvasContainerView {
        CanvasContainerView(session: session)
    }

    func updateNSView(_ view: CanvasContainerView, context: Context) {
        view.update(
            selection: session.selection?.frame, label: session.selectionLabel,
            inlineEdit: session.inlineEdit, interactiveEmbed: session.interactiveEmbed
        )
    }
}
