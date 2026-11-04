import Foundation

/// Command-line options, mainly for testing and automation:
///
///     Cue.app/Contents/MacOS/Cue -open /path/deck.html -present YES -slide 3
///
/// `-slide` is 1-based. UserDefaults parses `-key value` pairs for us.
enum LaunchOptions {
    static var deckToOpen: URL? {
        guard let path = UserDefaults.standard.string(forKey: "open"), !path.isEmpty else { return nil }
        return URL(filePath: (path as NSString).expandingTildeInPath)
    }

    static var presentImmediately: Bool { UserDefaults.standard.bool(forKey: "present") }

    static var startSlide: Int { max(0, UserDefaults.standard.integer(forKey: "slide") - 1) }
}
