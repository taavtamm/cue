import CueEditor
import CueUI
import SwiftUI

/// The panel under the slide: the slide's speaker notes, or its animation
/// timeline. Opens on Notes; the last choice is remembered.
struct SlideBottomPanel: View {
    enum Tab: String, CaseIterable { case notes = "Notes", timeline = "Timeline" }

    let session: EditorSession
    @AppStorage("editor.bottomPanelTab") private var tab = Tab.notes
    @State private var playheadStart = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SegmentedSwitch(selection: $tab, options: Tab.allCases) { $0.rawValue }
                    .fixedSize()
                switch tab {
                case .notes: NotesAccessory(session: session)
                case .timeline: TimelineAccessory(session: session, playheadStart: $playheadStart)
                }
            }
            switch tab {
            case .notes: SlideNotesEditor(session: session)
            case .timeline: TimelinePanel(session: session, playheadStart: $playheadStart)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 16))
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.07)))
        .padding(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
        .onChange(of: session.slide) { playheadStart = Date() }
    }
}

/// Where the notes are stored, beside the tab switch.
private struct NotesAccessory: View {
    let session: EditorSession

    var body: some View {
        Text("Speaker notes · \(location)")
            .font(.system(size: 11.5))
            .foregroundStyle(CueTheme.textTertiary)
        Spacer(minLength: 0)
    }

    private var location: String {
        switch session.structure.adapter {
        case .claudeDesign: "data-speaker-notes"
        case .cue: "data-cue-notes"
        case .reveal: "aside.notes"
        default: "in the HTML"
        }
    }
}

/// How many animations the slide has, and Preview, beside the tab switch.
private struct TimelineAccessory: View {
    let session: EditorSession
    @Binding var playheadStart: Date

    var body: some View {
        let count = session.timeline.rows.count
        Text(count == 0 ? "" : "Animations running on this slide · \(count) track\(count == 1 ? "" : "s")")
            .font(.system(size: 11.5))
            .foregroundStyle(CueTheme.textTertiary)
        Spacer(minLength: 0)
        Button {
            playheadStart = Date()
            Task { await session.replayAnimations() }
        } label: {
            Label("Preview", systemImage: "play.fill").font(.system(size: 11.5))
        }
        .buttonStyle(.cue(height: 26))
        .disabled(count == 0)
    }
}
