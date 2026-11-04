import CueUI
import SwiftUI

/// Every slide in order. Click one to jump there.
///
/// Cards show the number and title rather than a rendered picture: a live
/// WKWebView per thumbnail would cost a page load each, and Cue never shows
/// screenshots in place of the real deck.
struct SlideStrip: View {
    let model: PresenterModel

    var body: some View {
        ScrollViewReader { proxy in
            SnapshotFriendlyScrollView(axis: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(0..<model.slideCount, id: \.self) { index in
                        card(index).id(index)
                    }
                }
                .padding(4)
            }
            .onChange(of: model.position.slide, initial: true) { _, slide in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(slide, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("All slides")
    }

    private func card(_ index: Int) -> some View {
        let isCurrent = index == model.position.slide
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Button { model.actions.jump(index) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("\(index + 1)").font(.system(size: 11, weight: .bold).monospacedDigit())
                    if model.liveSlides.contains(index) { LiveTag() }
                }
                Text(model.label(of: index))
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color.white.opacity(0.8))
                Spacer(minLength: 0)
            }
            .foregroundStyle(CueTheme.text)
            .padding(8)
            .frame(width: 140, height: 79, alignment: .topLeading)
            .background(Color.white.opacity(isCurrent ? 0.12 : 0.05), in: shape)
            .overlay(shape.strokeBorder(isCurrent ? CueTheme.selection : Color.white.opacity(0.1),
                                        lineWidth: isCurrent ? 2.5 : 1))
            .opacity(index < model.position.slide ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Go to slide \(index + 1): \(model.label(of: index))")
    }
}
