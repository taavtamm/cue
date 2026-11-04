import Foundation

/// Hosts that only serve web fonts, so a stylesheet from them reads as
/// "fonts" rather than "styles" when Cue asks the user.
enum FontHosts {
    static let known: Set<String> = [
        "fonts.googleapis.com", "fonts.gstatic.com", "use.typekit.net", "p.typekit.net",
        "fonts.bunny.net", "rsms.me", "api.fontshare.com", "cdn.fontshare.com",
    ]

    static func isFontHost(_ host: String) -> Bool { known.contains(host) }
}
