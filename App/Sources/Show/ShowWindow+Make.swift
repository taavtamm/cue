import AppKit

extension ShowWindow {
    /// A borderless window covering `screen`, for presenting.
    static func covering(_ screen: NSScreen) -> ShowWindow {
        let window = ShowWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.collectionBehavior = [.fullScreenNone, .canJoinAllSpaces]
        window.level = .normal
        return window.configured()
    }

    /// An ordinary titled window, for rehearsing on one Mac.
    static func rehearsal(title: String, frame: CGRect) -> ShowWindow {
        let window = ShowWindow(
            contentRect: frame, styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.setFrame(frame, display: false)
        return window.configured()
    }

    private func configured() -> ShowWindow {
        backgroundColor = .black
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        return self
    }
}
