import CueEditor
import CueUI
import SwiftUI

/// The middle of the editor in Design mode: where the selection sits, the
/// real slide, the Ask bar, and the slide's notes or animation timeline.
struct DesignCanvasArea: View {
    @Bindable var session: EditorSession

    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbBar(session: session)
            CanvasView(session: session)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
                .shadow(color: .black.opacity(0.55), radius: 30, y: 24)
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            if let error = session.lastError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(CueTheme.destructiveText)
                    .padding(.top, 8)
                    .onTapGesture { session.lastError = nil }
            }
            EditorAskBar(session: session)
                .frame(height: 84)
            SlideBottomPanel(session: session)
                .frame(height: 190)
        }
    }

    private var aspectRatio: CGFloat {
        session.structure.canvas.width / max(1, session.structure.canvas.height)
    }
}

/// `section.deck-slide#3 › div.deck-scaler › h1.headline`, and the
/// Playing live / Paused toggle.
struct BreadcrumbBar: View {
    let session: EditorSession

    var body: some View {
        HStack(spacing: 8) {
            breadcrumb
            Spacer(minLength: 8)
            if !session.isPlayingLive {
                Text("Some scripted content can't be paused")
                    .font(.system(size: 11))
                    .foregroundStyle(CueTheme.textTertiary)
            }
            ZoomMenu(zoom: session.zoom)
            LivePlayToggle(isPlaying: session.isPlayingLive) { session.setPlayingLive(!session.isPlayingLive) }
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
    }

    private var breadcrumb: some View {
        let items = session.selection?.breadcrumb ?? []
        return HStack(spacing: 8) {
            if items.isEmpty {
                Text("Click an element to select it · double-click text to edit")
            }
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Text("›").accessibilityHidden(true) }
                Text(item).foregroundStyle(index == items.count - 1 ? CueTheme.selectionText : CueTheme.textTertiary)
            }
        }
        .font(.system(size: 11.5, design: .monospaced))
        .foregroundStyle(CueTheme.textTertiary)
        .lineLimit(1)
        .truncationMode(.head)
    }
}

/// "Playing live" with a pulsing green dot, or "Paused".
struct LivePlayToggle: View {
    let isPlaying: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 7) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: 10))
                if isPlaying { PulsingDot(CueTheme.successBright, diameter: 7) }
                Text(isPlaying ? "Playing live" : "Paused · frozen frame")
            }
            .font(.system(size: 11.5))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause live content in the editor" : "Play live content in the editor")
    }
}
