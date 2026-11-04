import CueEditor
import CueUI
import SwiftUI

/// The inspector on the right: Design / Animate / Notes.
struct InspectorPanel: View {
    enum Tab: String, CaseIterable { case design = "Design", animate = "Animate", notes = "Notes" }

    let session: EditorSession
    @State private var tab = Tab.design

    var body: some View {
        VStack(spacing: 0) {
            SegmentedSwitch(selection: $tab, options: Tab.allCases, fillsWidth: true) { $0.rawValue }
                .padding(10)
            switch tab {
            case .design: DesignInspector(session: session)
            case .animate: AnimateInspector(session: session)
            case .notes: NotesInspector(session: session)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: CueTheme.panelRadius))
        .overlay(RoundedRectangle(cornerRadius: CueTheme.panelRadius).strokeBorder(Color.white.opacity(0.07)))
    }
}
