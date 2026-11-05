import CueEditor
import CueUI
import SwiftUI

/// The slides, as real renders. Click to show one; drag to reorder; the
/// context menu duplicates, deletes or adds a slide after.
struct SlideSidebar: View {
    let session: EditorSession
    let thumbnails: ThumbnailStore
    let actions: EditorActions
    @Environment(\.isSnapshotRendering) private var isSnapshot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The gap a dragged slide would drop into, while one is dragged.
    @State private var dropGap: Int?

    var body: some View {
        Group {
            if isSnapshot { // ImageRenderer can't draw scroll views.
                Color.clear.overlay(alignment: .top) { cells }.clipped()
            } else {
                ScrollViewReader { scroller in
                    ScrollView { cells }
                        .scrollIndicators(.never)
                        .onChange(of: session.slide) {
                            guard ids.indices.contains(session.slide) else { return }
                            withAnimation { scroller.scrollTo(ids[session.slide], anchor: .center) }
                        }
                }
            }
        }
        .frame(width: 224)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: CueTheme.panelRadius))
        .clipShape(RoundedRectangle(cornerRadius: CueTheme.panelRadius)) // Scrolled cells stay inside the panel.
        .overlay(RoundedRectangle(cornerRadius: CueTheme.panelRadius).strokeBorder(Color.white.opacity(0.07)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Slides")
    }

    private var cells: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            header
            // Identified by slide, not position, so moves and deletes animate.
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                cell(index)
                    .id(id)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10))
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: ids)
    }

    private var ids: [String] { SlideIdentity.ids(session.structure.slides) }

    private var header: some View {
        HStack {
            SectionLabel("Slides")
            Spacer()
            IconButton("Add slide", systemImage: "plus", size: 26, iconSize: 13, action: actions.addSlide)
        }
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 6))
    }

    @ViewBuilder private func cell(_ index: Int) -> some View {
        if isSnapshot { thumbnail(index) } else { interactive(thumbnail(index), index) }
    }

    private func thumbnail(_ index: Int) -> some View {
        let slide = session.structure.slides[index]
        return SlideThumbnailCell(
            number: index + 1, image: thumbnails.images[index],
            label: slide.label.isEmpty ? "Slide \(index + 1)" : slide.label,
            isSelected: index == session.slide,
            aspectRatio: session.structure.canvas.width / max(1, session.structure.canvas.height)
        )
    }

    /// Click to show, drag to reorder, and the context menu. Not in snapshots,
    /// which can't draw drag sources.
    private func interactive(_ cell: some View, _ index: Int) -> some View {
        SlideSidebarRow(index: index, count: ids.count, gap: $dropGap, cell: cell) { from, gap in
            if let to = SlideReorder.destination(moving: from, toGap: gap) { actions.moveSlide(from, to) }
        }
            .onTapGesture {
                // Take the keyboard back from the notes or Ask bar, so ↑ ↓ change slides.
                NSApp.keyWindow?.makeFirstResponder(nil)
                session.keyFocus = .sidebar
                session.showSlide(index)
            }
            .contextMenu {
                Button("Add Slide After") {
                    session.showSlide(index)
                    actions.addSlide()
                }
                Button("Duplicate") { actions.duplicateSlide(index) }
                Divider()
                Button("Delete Slide", role: .destructive) { actions.deleteSlide(index) }
                    .disabled(session.slideCount <= 1)
            }
    }
}
