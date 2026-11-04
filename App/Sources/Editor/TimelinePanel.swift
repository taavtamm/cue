import CueEditor
import CueUI
import SwiftUI

/// The slide's animations, read from the page (`document.getAnimations()`),
/// as bars on a time ruler with a moving playhead. Preview replays them.
struct TimelinePanel: View {
    let session: EditorSession
    @State private var playheadStart = Date()

    var body: some View {
        let layout = session.timeline
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Timeline").font(.system(size: 12, weight: .semibold))
                Text(caption(layout)).font(.system(size: 11.5)).foregroundStyle(CueTheme.textTertiary)
                Spacer()
                Button {
                    playheadStart = Date()
                    Task { await session.replayAnimations() }
                } label: {
                    Label("Preview", systemImage: "play.fill").font(.system(size: 11.5))
                }
                .buttonStyle(.cue(height: 26))
                .disabled(layout.rows.isEmpty)
            }
            if layout.rows.isEmpty {
                Text("No animations on this slide.").font(.system(size: 11.5)).foregroundStyle(CueTheme.textTertiary)
                Spacer(minLength: 0)
            } else {
                tracks(layout)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.07)))
        .padding(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
        .onChange(of: session.slide) { playheadStart = Date() }
    }

    private func caption(_ layout: TimelineLayout) -> String {
        let count = layout.rows.count
        return count == 0 ? "" : "Animations running on this slide · \(count) track\(count == 1 ? "" : "s")"
    }

    private func tracks(_ layout: TimelineLayout) -> some View {
        SnapshotFriendlyScrollView(axis: .vertical) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                GridRow {
                    Color.clear.frame(width: 150, height: 1)
                    ruler(layout)
                }
                ForEach(layout.rows) { row in
                    GridRow {
                        Text(row.title).font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.8))
                            .lineLimit(1).frame(width: 150, alignment: .leading)
                        TimelineTrack(start: row.start, width: row.width, style: style(row), tint: tint(row))
                            .overlay { playhead(layout) }
                    }
                }
            }
        }
    }

    private func ruler(_ layout: TimelineLayout) -> some View {
        HStack {
            ForEach(layout.ticks, id: \.self) { tick in
                Text("\(tick)s")
                if tick != layout.ticks.last { Spacer() }
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.5))
    }

    /// A white line sweeping across the span, restarted by Preview.
    private func playhead(_ layout: TimelineLayout) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !session.isPlayingLive)) { context in
            GeometryReader { geometry in
                let elapsed = context.date.timeIntervalSince(playheadStart).truncatingRemainder(dividingBy: layout.span)
                Rectangle().fill(Color.white).frame(width: 2)
                    .shadow(color: .white.opacity(0.8), radius: 4)
                    .offset(x: geometry.size.width * elapsed / layout.span)
            }
        }
        .allowsHitTesting(false)
    }

    private func style(_ row: TimelineLayout.Row) -> TimelineTrack.Style {
        row.isEmbed ? .embed : (row.loops ? .loop : .animation)
    }

    private func tint(_ row: TimelineLayout.Row) -> Color {
        let palette = [CueTheme.selection, CueTheme.violet, Color(hex: 0xFFB35E), CueTheme.successBright]
        return palette[row.id % palette.count]
    }
}
