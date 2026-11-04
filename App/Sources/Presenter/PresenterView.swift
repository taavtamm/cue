import CueRender
import CueUI
import SwiftUI

/// The presenter's screen: timer and controls on top, the live current slide
/// with the strip below, and the next slide and notes on the right.
struct PresenterView: View {
    let model: PresenterModel
    let current: SlideRenderer
    let next: SlideRenderer

    var body: some View {
        GeometryReader { geometry in
            content(sideWidth: min(440, max(300, geometry.size.width * 0.32)))
        }
        .foregroundStyle(CueTheme.text)
        .background(PresenterBackground())
    }

    /// The right column is 440 pt as designed, narrower in small rehearsal windows.
    private func content(sideWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            PresenterHeader(model: model)
            if model.showsFocusWarning && !model.isRehearsal {
                FocusHint.banner { model.showsFocusWarning = false }
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 18) {
                    CurrentSlidePanel(model: model, renderer: current)
                    PresenterControls(model: model)
                    SlideStrip(model: model).frame(height: 92)
                    Spacer(minLength: 0)
                    if !model.isRehearsal { PresenterInfoRow(model: model) }
                }
                VStack(alignment: .leading, spacing: 20) {
                    NextSlidePanel(model: model, renderer: next)
                    NotesPanel(model: model)
                }
                .frame(width: sideWidth)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 24, bottom: 24, trailing: 24))
    }
}

/// Near-black with a faint blue wash from the top, as in the design.
struct PresenterBackground: View {
    var body: some View {
        ZStack {
            Color(hex: 0x08080B)
            RadialGradient(
                colors: [CueTheme.siriGlowColors[2].opacity(0.16), .clear],
                center: UnitPoint(x: 0.3, y: -0.1), startRadius: 0, endRadius: 900
            )
        }
        .ignoresSafeArea()
    }
}
