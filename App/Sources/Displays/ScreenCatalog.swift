import AppKit
import CueCore

/// The bridge between NSScreen and CueCore's `DisplayInfo`.
@MainActor
enum ScreenCatalog {
    static func displays() -> [DisplayInfo] {
        NSScreen.screens.map(info)
    }

    static func screen(for displayID: String) -> NSScreen? {
        NSScreen.screens.first { id(of: $0) == displayID }
    }

    /// The display's UUID, which survives reconnects and reboots. Falls back
    /// to the display number when macOS has no UUID for it.
    static func id(of screen: NSScreen) -> String {
        let number = displayNumber(of: screen)
        if let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue(),
           let text = CFUUIDCreateString(nil, uuid) as String? {
            return text
        }
        return "display-\(number)"
    }

    private static func info(_ screen: NSScreen) -> DisplayInfo {
        let number = displayNumber(of: screen)
        let scale = screen.backingScaleFactor
        return DisplayInfo(
            id: id(of: screen),
            name: screen.localizedName,
            frame: screen.frame,
            pixelWidth: Int(screen.frame.width * scale),
            pixelHeight: Int(screen.frame.height * scale),
            isBuiltIn: CGDisplayIsBuiltin(number) != 0,
            isMain: screen == NSScreen.screens.first
        )
    }

    private static func displayNumber(of screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
    }
}
