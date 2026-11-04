import CueRender
import CueUI
import SwiftUI

/// For a floor or lectern screen: a big next slide, a big timer, where the
/// show is, and the start of the current notes. Readable from a distance.
struct ConfidenceView: View {
    let model: PresenterModel
    let next: SlideRenderer

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            NextSlidePanel(model: model, renderer: next, titleSize: 18)
            VStack(alignment: .leading, spacing: 18) {
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    let elapsed = model.controller.elapsed
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ElapsedTimer.format(elapsed))
                            .font(.system(size: 120, weight: .semibold).monospacedDigit())
                            .tracking(-3)
                        Text(model.pace(at: elapsed).text)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(CueTheme.textSecondary)
                    }
                }
                PositionCounter(slide: model.position.slide, slideCount: model.slideCount,
                                build: model.position.build, buildCount: model.buildCount)
                    .scaleEffect(1.4, anchor: .leading)
                    .padding(.vertical, 8)
                if model.showsFocusWarning {
                    FocusHint.banner { model.showsFocusWarning = false }
                }
                Text(model.currentNotes)
                    .font(.system(size: 30))
                    .lineSpacing(8)
                    .lineLimit(6)
                Spacer(minLength: 0)
            }
            .frame(width: 520, alignment: .leading)
        }
        .padding(40)
        .foregroundStyle(CueTheme.text)
        .background(Color.black.ignoresSafeArea())
    }
}
