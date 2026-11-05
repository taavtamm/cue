import AppKit
import CueCore
import CueRender
import SwiftUI

/// One show window and the slide renderers inside it. A stage or mirror is
/// a single renderer; the presenter view has the current and next slide.
@MainActor
final class ShowSurface {
    let role: DisplayRole
    let window: ShowWindow
    let renderers: [SlideRenderer]
    /// The SwiftUI root, for Debug snapshots. Nil for a bare stage.
    let chrome: AnyView?

    private init(role: DisplayRole, window: ShowWindow, renderers: [SlideRenderer], chrome: AnyView? = nil) {
        self.role = role
        self.window = window
        self.renderers = renderers
        self.chrome = chrome
    }

    /// The stage renderer, if this surface shows the audience's slide.
    var stage: SlideRenderer? { renderers.first { $0.surface == .stage } }

    /// In rehearsal there is no stage window, so the presenter's current slide
    /// takes the stage's job (auto-builds, live-content reports).
    static func make(role: DisplayRole, window: ShowWindow, model: PresenterModel) -> ShowSurface? {
        switch role {
        case .stage, .mirror:
            let renderer = SlideRenderer(surface: role == .stage ? .stage : .mirror)
            window.contentView = renderer
            return ShowSurface(role: role, window: window, renderers: [renderer])
        case .presenter:
            let current = SlideRenderer(surface: model.isRehearsal ? .stage : .presenterCurrent)
            let next = SlideRenderer(surface: .nextPreview)
            let view = PresenterView(model: model, current: current, next: next)
            window.contentView = NSHostingView(rootView: view)
            return ShowSurface(role: role, window: window, renderers: [current, next], chrome: AnyView(view))
        case .confidence:
            let next = SlideRenderer(surface: .nextPreview)
            let view = ConfidenceView(model: model, next: next)
            window.contentView = NSHostingView(rootView: view)
            return ShowSurface(role: role, window: window, renderers: [next], chrome: AnyView(view))
        case .off: // Black, so the desktop and other windows never show during the show.
            let blank = NSView()
            blank.wantsLayer = true
            blank.layer?.backgroundColor = NSColor.black.cgColor
            window.contentView = blank
            return ShowSurface(role: role, window: window, renderers: [])
        }
    }

    func close() {
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }
}
