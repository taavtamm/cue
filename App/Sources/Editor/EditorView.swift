import CueCore
import CueEditor
import CueUI
import SwiftUI

/// The editor window's content, as in the design. The window itself is the
/// tinted glass (see `NSWindow.useCueGlass`); the toolbar shares its row
/// with the traffic lights; slides, the real slide and the inspector below.
struct EditorView: View {
    @Bindable var session: EditorSession
    let thumbnails: ThumbnailStore
    let actions: EditorActions
    let networkBanner: AnyView
    @State private var showsSidebar = true

    var body: some View {
        VStack(spacing: 0) {
            EditorToolbar(session: session, actions: actions, showsSidebar: $showsSidebar)
            networkBanner
            HStack(spacing: 0) {
                if showsSidebar {
                    SlideSidebar(session: session, thumbnails: thumbnails, actions: actions)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                centre.frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.mode == .design {
                    InspectorPanel(session: session).frame(width: 296)
                }
            }
            .padding(EdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8))
            // A click on empty window space (around the canvas, by the Ask bar…)
            // deselects. Not on the toolbar row, which drags the window.
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { session.clearSelection() }
            }
        }
        .foregroundStyle(CueTheme.text)
        .animation(.easeOut(duration: 0.18), value: showsSidebar)
    }

    @ViewBuilder private var centre: some View {
        switch session.mode {
        case .design: DesignCanvasArea(session: session)
        case .html: HTMLSourcePanel(session: session)
        case .outline: OutlinePanel(session: session)
        }
    }
}

/// What the editor's buttons do. Set by the window controller, which owns
/// the show, the Displays window and the document lifecycle.
struct EditorActions {
    var play: (_ fromSlide: Int) -> Void = { _ in }
    var rehearse: () -> Void = {}
    var showDisplays: () -> Void = {}
    var addSlide: () -> Void = {}
    var duplicateSlide: (Int) -> Void = { _ in }
    var deleteSlide: (Int) -> Void = { _ in }
    var moveSlide: (_ from: Int, _ to: Int) -> Void = { _, _ in }
}
