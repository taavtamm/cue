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

    var body: some View {
        Group {
            if isSnapshot { // ImageRenderer can't draw scroll views.
                Color.clear.overlay(alignment: .top) { cells }.clipped()
            } else {
                ScrollViewReader { scroller in
                    ScrollView { cells }
                        .scrollIndicators(.never)
                        .onChange(of: session.slide) {
                            withAnimation { scroller.scrollTo(session.slide, anchor: .center) }
                        }
                }
            }
        }
        .frame(width: 224)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: CueTheme.panelRadius))
        .overlay(RoundedRectangle(cornerRadius: CueTheme.panelRadius).strokeBorder(Color.white.opacity(0.07)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Slides")
    }

    private var cells: some View {
        LazyVStack(alignment: .leading, spacing: 4) {
            header
            ForEach(session.structure.slides.indices, id: \.self) { index in
                cell(index).id(index)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 16, trailing: 10))
    }

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
            isLive: session.liveSlides.contains(index), isSelected: index == session.slide,
            aspectRatio: session.structure.canvas.width / max(1, session.structure.canvas.height)
        )
    }

    /// Click to show, drag to reorder, and the context menu. Not in snapshots,
    /// which can't draw drag sources.
    private func interactive(_ cell: some View, _ index: Int) -> some View {
        cell
            .onTapGesture { session.showSlide(index) }
            .draggable(SlideDrag(index: index))
            .dropDestination(for: SlideDrag.self) { items, _ in
                guard let from = items.first?.index, from != index else { return false }
                actions.moveSlide(from, index)
                return true
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

/// A slide being dragged within the sidebar.
struct SlideDrag: Codable, Transferable {
    let index: Int
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
