import CueCore
import CueEditor
import CueUI
import SwiftUI

/// Every slide's title and notes in one list. Titles are editable where the
/// deck stores them in `data-label`; notes wherever the deck keeps them.
struct OutlinePanel: View {
    let session: EditorSession

    var body: some View {
        SnapshotFriendlyScrollView(axis: .vertical) {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(session.structure.slides.indices, id: \.self) { index in
                    OutlineRow(session: session, index: index)
                }
            }
            .padding(EdgeInsets(top: 8, leading: 24, bottom: 24, trailing: 24))
        }
    }
}

private struct OutlineRow: View {
    let session: EditorSession
    let index: Int
    @State private var notes = ""
    @Environment(\.isSnapshotRendering) private var isSnapshot

    var body: some View {
        let slide = session.structure.slides[index]
        HStack(alignment: .top, spacing: 14) {
            Text("\(index + 1)").font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(CueTheme.textTertiary).frame(width: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    InspectorField("Title", value: slide.label, placement: .leading, isEditable: hasLabelAttribute) {
                        rename(slide, to: $0)
                    }
                    if session.liveSlides.contains(index) { LiveTag() }
                }
                notesField
                    .frame(minHeight: 54)
                    .padding(8)
                    .background(CueTheme.insetFill, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(
            Color.white.opacity(index == session.slide ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 14)
        )
        .onAppear { notes = slide.notes }
        .onChange(of: notes) {
            if notes != session.structure.slides[index].notes { session.setNotesWhileTyping(notes, slide: index) }
        }
    }

    @ViewBuilder private var notesField: some View {
        if isSnapshot { // ImageRenderer can't draw the AppKit text view.
            Text(notes).font(.system(size: 13.5)).frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            GlowTextField("Speaker notes", text: $notes, style: .notes)
        }
    }

    private func rename(_ slide: SlideInfo, to title: String) {
        Task { await session.apply(.setAttribute(slide.elementPath, name: "data-label", value: title)) }
    }

    private var hasLabelAttribute: Bool {
        let slide = session.structure.slides[index]
        return session.document.sourceMap.element(at: slide.elementPath)?.attributes["data-label"] != nil
    }
}
