import Foundation

/// Tries adapters in order and uses the first that recognises the deck. The
/// standard order goes from most to least explicit: Cue's own markup, Claude
/// Design decks, reveal.js, semantic slide roles, then the fallback, which
/// always answers, so every HTML file opens as something.
public struct AdapterRegistry: Sendable {
    public let adapters: [any DeckAdapter]

    public init(adapters: [any DeckAdapter]) {
        self.adapters = adapters
    }

    public static let standard = AdapterRegistry(adapters: [
        CueConventionAdapter(),
        ClaudeDesignAdapter(),
        RevealAdapter(),
        DocumentRoleAdapter(),
        FallbackAdapter(),
    ])

    public func structure(for input: AdapterInput) -> DeckStructure {
        for adapter in adapters {
            if let structure = adapter.detect(input) { return structure }
        }
        return FallbackAdapter().detect(input) ?? FallbackAdapter.wholePage(input)
    }
}
