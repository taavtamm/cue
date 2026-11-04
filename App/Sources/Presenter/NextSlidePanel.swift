import CueRender
import CueUI
import SwiftUI

/// The next slide in its finished state (or the next build), rendered live.
struct NextSlidePanel: View {
    let model: PresenterModel
    let renderer: SlideRenderer
    var titleSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(model.nextTitle, size: titleSize).lineLimit(1)
            RendererView(renderer: renderer)
                .aspectRatio(model.canvas.width / model.canvas.height, contentMode: .fit)
                .overlay { if !model.hasNext { endOfShow } }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.nextTitle)
    }

    private var endOfShow: some View {
        ZStack {
            Color.black
            Text("End of show").font(.system(size: 16, weight: .semibold)).foregroundStyle(CueTheme.textSecondary)
        }
    }
}

/// Speaker notes in large text, with A− / A+.
struct NotesPanel: View {
    let model: PresenterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("Notes", size: 12)
                Spacer()
                sizeButton("A", size: 12, label: "Smaller notes text", action: model.smallerNotes)
                sizeButton("A", size: 16, label: "Larger notes text", action: model.biggerNotes)
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 10, trailing: 14))
            SnapshotFriendlyScrollView(axis: .vertical) {
                Text(notes)
                    .font(.system(size: model.notesSize))
                    .lineSpacing(model.notesSize * 0.35)
                    .foregroundStyle(model.currentNotes.isEmpty ? CueTheme.textSecondary : CueTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 22, trailing: 22))
            }
        }
        .cueGlass(GlassPanelStyle(cornerRadius: 18, tint: Color(white: 0.11, opacity: 0.6)))
    }

    private var notes: String {
        model.currentNotes.isEmpty ? "No notes for this slide." : model.currentNotes
    }

    private func sizeButton(_ text: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: size, weight: size > 12 ? .semibold : .regular)).frame(width: 32, height: 30)
        }
        .buttonStyle(.cue(.glass, height: 30))
        .accessibilityLabel(label)
    }
}

/// Which screens are doing what, at the bottom of the presenter view.
struct PresenterInfoRow: View {
    let model: PresenterModel

    var body: some View {
        HStack(spacing: 16) {
            item("Stage", model.stageName ?? "No audience screen")
            item("Confidence monitor", model.confidenceName ?? "None")
            item("Rendering", model.renderingSummary)
        }
        .padding(.horizontal, 20)
        .frame(height: 78)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
    }

    private func item(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 12)).foregroundStyle(CueTheme.textTertiary)
            Text(value).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
