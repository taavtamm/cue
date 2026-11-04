import CueUI
import SwiftUI

/// The strip under the preview: deck title and facts, slide stepper, Play.
/// Temporary until the Editor milestone replaces this window.
struct DeckBar: View {
    let model: DeckPreviewModel
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.title).font(.system(size: 14, weight: .semibold))
                Text(model.summary).font(.system(size: 11.5)).foregroundStyle(CueTheme.textSecondary)
            }
            Spacer(minLength: 12)
            stepper
            PlayButton(action: onPlay)
                .help("Play slideshow (⌥⌘P)")
        }
        .foregroundStyle(CueTheme.text)
        .padding(.horizontal, 20)
        .frame(height: 64)
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            IconButtonBare(systemName: "chevron.left", label: "Previous slide", action: onPrevious)
            HStack(spacing: 6) {
                Text("\(model.slide + 1) / \(model.slideCount)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                if model.liveSlides.contains(model.slide) { LiveTag() }
            }
            .frame(minWidth: 90)
            IconButtonBare(systemName: "chevron.right", label: "Next slide", action: onNext)
        }
    }
}

/// A borderless symbol button for the stepper.
private struct IconButtonBare: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
