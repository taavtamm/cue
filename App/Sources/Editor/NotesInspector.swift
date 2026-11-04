import CueEditor
import CueUI
import SwiftUI

/// The slide's speaker notes, written back where the deck keeps them
/// (`data-speaker-notes` for this deck). Typing pauses merge into one undo.
struct NotesInspector: View {
    let session: EditorSession
    @State private var text = ""
    @State private var slide = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Speaker notes · \(notesLocation)")
            GlowTextField("Notes for this slide", text: $text, style: .notes)
                .padding(12)
                .frame(maxHeight: .infinity)
                .background(CueTheme.insetFill, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
        }
        .padding(EdgeInsets(top: 4, leading: 16, bottom: 16, trailing: 16))
        .onAppear(perform: load)
        .onChange(of: session.slide) { load() }
        .onChange(of: session.currentSlide?.notes) { // Undo, redo, or Claude changed them.
            if let notes = session.currentSlide?.notes, notes != text { text = notes }
        }
        .onChange(of: text) {
            guard slide == session.slide, text != session.currentSlide?.notes else { return }
            session.setNotesWhileTyping(text, slide: slide)
        }
    }

    private func load() {
        slide = session.slide
        text = session.currentSlide?.notes ?? ""
    }

    private var notesLocation: String {
        switch session.structure.adapter {
        case .claudeDesign: "data-speaker-notes"
        case .cue: "data-cue-notes"
        case .reveal: "aside.notes"
        default: "in the HTML"
        }
    }
}
