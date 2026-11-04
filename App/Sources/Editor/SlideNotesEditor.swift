import CueEditor
import CueUI
import SwiftUI

/// The slide's speaker notes, written back where the deck keeps them
/// (`data-speaker-notes` for this deck). Typing pauses merge into one undo.
struct SlideNotesEditor: View {
    let session: EditorSession
    @State private var text = ""
    @State private var slide = -1

    var body: some View {
        GlowTextField("Notes for this slide", text: $text, style: .notes)
            .padding(12)
            .frame(maxHeight: .infinity)
            .background(CueTheme.insetFill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.08)))
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
}
