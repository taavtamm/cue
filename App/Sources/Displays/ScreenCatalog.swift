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

    /// The display's UUID, which survives reconnects and reboots, so a room
    /// gets its roles back. Two identical monitors without serial numbers
    /// can share a UUID; then each also gets its display number, so they
    /// keep separate roles. Falls back to the number when there's no UUID.
    static func id(of screen: NSScreen) -> String {
        let number = displayNumber(of: screen)
        guard let own = uuid(of: number) else { return "display-\(number)" }
        let sharing = NSScreen.screens.filter { uuid(of: displayNumber(of: $0)) == own }.count
        return sharing > 1 ? "\(own)-\(number)" : own
    }

    private static func uuid(of number: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String?
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
