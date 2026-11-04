import CueEditor
import CueUI
import SwiftUI

/// The slide's animations, read from the page (`document.getAnimations()`),
/// as bars on a time ruler with a moving playhead.
struct TimelinePanel: View {
    let session: EditorSession
    /// Restarted by Preview and on slide change (owned by `SlideBottomPanel`).
    @Binding var playheadStart: Date

    var body: some View {
        let layout = session.timeline
        if layout.rows.isEmpty {
            Text("No animations on this slide.").font(.system(size: 11.5)).foregroundStyle(CueTheme.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            tracks(layout)
        }
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
        row.loops ? .loop : .animation
    }

    private func tint(_ row: TimelineLayout.Row) -> Color {
        let palette = [CueTheme.selection, CueTheme.violet, Color(hex: 0xFFB35E), CueTheme.successBright]
        return palette[row.id % palette.count]
    }
}
