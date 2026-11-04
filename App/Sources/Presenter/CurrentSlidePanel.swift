import CueRender
import CueUI
import SwiftUI

/// The live current slide, exactly as the audience sees it, with status pills.
struct CurrentSlidePanel: View {
    let model: PresenterModel
    let renderer: SlideRenderer

    var body: some View {
        RendererView(renderer: renderer)
            .aspectRatio(model.canvas.width / model.canvas.height, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { if model.controller.isBlack || model.controller.isWhite { blankNotice } }
            .overlay(alignment: .topLeading) { Pill("On stage", .status(dot: CueTheme.destructive)).padding(14) }
            .overlay(alignment: .topTrailing) {
                if model.liveSlides.contains(model.position.slide) {
                    Pill("Live web content · playing", .status(dot: CueTheme.live)).padding(14)
                }
            }
            .shadow(color: .black.opacity(0.6), radius: 40, y: 30)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
            .accessibilityLabel("Current slide: \(model.label(of: model.position.slide))")
    }

    /// The presenter still sees the slide; this says what the audience sees.
    private var blankNotice: some View {
        ZStack {
            Color.black.opacity(0.55)
            Text(model.controller.isBlack ? "Audience sees a black screen · press B" : "Audience sees white · press W")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CueTheme.text)
        }
    }
}

/// Previous, the main advance button, and the clicker hint.
struct PresenterControls: View {
    let model: PresenterModel

    var body: some View {
        HStack(spacing: 12) {
            Button(action: model.actions.previous) {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).frame(width: 36)
            }
            .buttonStyle(.cue(.glass, height: 52))
            .accessibilityLabel("Previous")
            Button(action: model.actions.next) {
                HStack(spacing: 8) {
                    Text(model.advanceTitle).font(.system(size: 15, weight: .semibold))
                    Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold))
                }
                .frame(width: 196)
            }
            .buttonStyle(.cue(.primary, height: 52))
            .disabled(!model.hasNext)
            Text("Space, → or clicker · type a number and Return to jump")
                .font(.system(size: 12.5))
                .foregroundStyle(CueTheme.textTertiary)
                .padding(.leading, 6)
            Spacer(minLength: 0)
        }
    }
}
