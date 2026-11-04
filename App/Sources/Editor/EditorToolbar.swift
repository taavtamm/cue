import AppKit
import CueEditor
import CueUI
import SwiftUI

/// Title and facts on the left, Add Slide · Play · play options in the
/// centre, mode switch, Displays and Rehearse on the right.
struct EditorToolbar: View {
    @Bindable var session: EditorSession
    let actions: EditorActions
    @Binding var showsSidebar: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 14) {
                IconButton("Toggle sidebar", systemImage: "sidebar.left", size: 34, iconSize: 16) {
                    showsSidebar.toggle()
                }
                .padding(.leading, 70) // Clear of the window's traffic lights.
                titleBlock
                Spacer(minLength: 16)
                SegmentedSwitch(selection: $session.mode, options: EditorMode.allCases) { $0.title }
                Button(action: actions.showDisplays) {
                    Label(displaysTitle, systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.cue(height: 34))
                Button(action: actions.rehearse) { Label("Rehearse", systemImage: "timer") }
                    .buttonStyle(.cue(height: 34))
            }
            playCluster
        }
        .padding(.horizontal, 16)
        .frame(height: NSWindow.cueToolbarHeight)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                Text(session.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                if session.isDirty {
                    Circle().fill(CueTheme.textSecondary).frame(width: 6, height: 6)
                        .accessibilityLabel("Unsaved changes")
                }
            }
            TimelineView(.everyMinute) { _ in
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(CueTheme.textTertiary).lineLimit(1)
            }
        }
    }

    private var playCluster: some View {
        HStack(spacing: 10) {
            IconButton("Add slide", systemImage: "plus.rectangle", size: 40, iconSize: 17, action: actions.addSlide)
            PlayButton { actions.play(session.slide) }
                .help("Play from this slide (⌥⌘P)")
            Menu {
                Button("Play from Start") { actions.play(0) }
                Button("Play from Current Slide") { actions.play(session.slide) }
                Divider()
                Button("Rehearse on This Mac", action: actions.rehearse)
                Button("Displays…", action: actions.showDisplays)
            } label: {
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .frame(width: 24, height: 40)
            .foregroundStyle(Color.white.opacity(0.7))
            .accessibilityLabel("Play options")
            .padding(.leading, -6)
        }
    }

    private var subtitle: String {
        guard let date = session.editedAt else { return session.summary }
        let edited = Date().timeIntervalSince(date) < 60
            ? "Edited just now"
            : "Edited " + date.formatted(.relative(presentation: .named))
        return "\(session.summary) · \(edited)"
    }

    private var displaysTitle: String {
        let count = NSScreen.screens.count
        return count == 1 ? "1 Display" : "\(count) Displays"
    }
}
