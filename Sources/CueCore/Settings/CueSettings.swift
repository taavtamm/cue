import Foundation
import Observation

/// Cue's app-wide preferences (Settings window), stored in UserDefaults.
/// Per-deck choices live in the deck's sidecar (`CueSidecar`), and network and
/// device grants in `DeckGrantStore`.
@MainActor @Observable
public final class CueSettings {
    public static let shared = CueSettings()
    /// The font name meaning "the system font stack".
    public nonisolated static let systemFont = "System"

    public enum Defaults {
        public static let minutesPerSlide: Double = 2
        public static let cursorHideDelay: Double = 2
        public static let fontSize: Double = 48
    }

    /// Where New Presentation suggests saving. Nil = the Save panel's default.
    public var defaultSaveFolder: URL? { didSet { store(defaultSaveFolder?.path, .saveFolder) } }
    /// Used for the talk length when a deck has no target and no rehearsal.
    public var minutesPerSlide: Double { didSet { clampAndStore(\.minutesPerSlide, 0.5...30, .minutesPerSlide) } }
    /// Seconds without mouse movement before the cursor hides during a show.
    public var cursorHideDelay: Double { didSet { clampAndStore(\.cursorHideDelay, 0.5...30, .cursorHideDelay) } }
    public var keepsDisplayAwake: Bool { didSet { store(keepsDisplayAwake, .keepsDisplayAwake) } }
    /// Mirrored screens line their animations up after each slide change.
    public var keepsAnimationsInSync: Bool { didSet { store(keepsAnimationsInSync, .keepsAnimationsInSync) } }
    /// Font for new text boxes and new decks.
    public var defaultFontFamily: String { didSet { store(defaultFontFamily, .fontFamily) } }
    public var defaultFontSize: Double { didSet { clampAndStore(\.defaultFontSize, 8...400, .fontSize) } }
    /// Keep Claude's edits without asking (Settings › Claude). On by default:
    /// Claude's edits are kept immediately, each still undoable on its own.
    /// Turned off, every edit waits for Accept or Undo.
    public var autoAcceptClaudeEdits: Bool { didSet { store(autoAcceptClaudeEdits, .autoAcceptClaude) } }
    /// Pause the editor's live slide while another app is active (Settings ›
    /// Editor). On by default: heavy decks otherwise keep the GPU busy behind
    /// other windows. It still plays while Claude is editing.
    public var pausesLiveContentInBackground: Bool {
        didSet { store(pausesLiveContentInBackground, .pausesInBackground) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultSaveFolder = defaults.string(forKey: Key.saveFolder.rawValue).map { URL(filePath: $0) }
        minutesPerSlide = defaults.object(forKey: Key.minutesPerSlide.rawValue) as? Double ?? Defaults.minutesPerSlide
        cursorHideDelay = defaults.object(forKey: Key.cursorHideDelay.rawValue) as? Double ?? Defaults.cursorHideDelay
        keepsDisplayAwake = defaults.object(forKey: Key.keepsDisplayAwake.rawValue) as? Bool ?? true
        keepsAnimationsInSync = defaults.object(forKey: Key.keepsAnimationsInSync.rawValue) as? Bool ?? true
        defaultFontFamily = defaults.string(forKey: Key.fontFamily.rawValue) ?? Self.systemFont
        defaultFontSize = defaults.object(forKey: Key.fontSize.rawValue) as? Double ?? Defaults.fontSize
        // On by default: Claude's edits are kept at once, each undoable on its own.
        autoAcceptClaudeEdits = defaults.object(forKey: Key.autoAcceptClaude.rawValue) as? Bool ?? true
        pausesLiveContentInBackground = defaults.object(forKey: Key.pausesInBackground.rawValue) as? Bool ?? true
    }

    /// Back to Cue's defaults (the save folder is cleared too).
    public func reset() {
        defaultSaveFolder = nil
        minutesPerSlide = Defaults.minutesPerSlide
        cursorHideDelay = Defaults.cursorHideDelay
        keepsDisplayAwake = true
        keepsAnimationsInSync = true
        defaultFontFamily = Self.systemFont
        defaultFontSize = Defaults.fontSize
        autoAcceptClaudeEdits = true
        pausesLiveContentInBackground = true
    }

    /// UserDefaults keys. `keepsAnimationsInSync` keeps the key the Displays
    /// window already used, so existing choices carry over.
    enum Key: String {
        case saveFolder = "cue.defaultSaveFolder"
        case minutesPerSlide = "cue.minutesPerSlide"
        case cursorHideDelay = "cue.cursorHideDelay"
        case keepsDisplayAwake = "cue.keepsDisplayAwake"
        case keepsAnimationsInSync = "keepsAnimationsInSync"
        case fontFamily = "cue.defaultFontFamily"
        case fontSize = "cue.defaultFontSize"
        case autoAcceptClaude = "cue.autoAcceptClaudeEdits"
        case pausesInBackground = "cue.pausesLiveContentInBackground"
    }

    private func store(_ value: Any?, _ key: Key) {
        if let value { defaults.set(value, forKey: key.rawValue) } else { defaults.removeObject(forKey: key.rawValue) }
    }

    private func clampAndStore(_ path: ReferenceWritableKeyPath<CueSettings, Double>, _ range: ClosedRange<Double>,
                               _ key: Key) {
        let clamped = min(max(self[keyPath: path], range.lowerBound), range.upperBound)
        if clamped != self[keyPath: path] { self[keyPath: path] = clamped } // Re-enters once, already in range.
        store(clamped, key)
    }
}
