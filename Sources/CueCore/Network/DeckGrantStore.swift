import Foundation

/// Where the user's per-deck network and device choices live: one JSON file
/// in Cue's Application Support folder, keyed by the deck's resolved path.
///
/// Not in the deck's sidecar on purpose. Anyone can put a `deck.cue.json`
/// beside a deck they hand out, so a sidecar must never be able to allow a
/// host or turn on the camera. A deck's page can't write here: it reads only
/// its own folder and has no file access at all.
public struct DeckGrantStore: Sendable {
    /// The JSON file: `{ "<resolved deck path>": DeckGrants }`.
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/Library/Application Support/Cue/deck-grants.json` (inside the app's
    /// container when sandboxed).
    public static var standard: DeckGrantStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return DeckGrantStore(fileURL: support.appending(path: "Cue/deck-grants.json"))
    }

    /// The key for a deck: its absolute path with symlinks resolved, so two
    /// names for one file share their choices.
    public static func key(forDeck deckURL: URL) -> String {
        deckURL.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// The deck's choices; nothing allowed when the store is missing or unreadable.
    public func grants(forDeck deckURL: URL) -> DeckGrants {
        ((try? load()) ?? [:])[Self.key(forDeck: deckURL)] ?? .none
    }

    /// Every deck with choices, by resolved path.
    public func all() -> [String: DeckGrants] {
        (try? load()) ?? [:]
    }

    /// Reads the store, applies `change` to this deck's choices, and saves.
    /// A store that exists but can't be read is never replaced: the error is
    /// thrown and the file stays as it is.
    @discardableResult
    public func update(forDeck deckURL: URL, _ change: (inout DeckGrants) -> Void) throws -> DeckGrants {
        var everything = try load()
        let key = Self.key(forDeck: deckURL)
        var grants = everything[key] ?? .none
        change(&grants)
        everything[key] = grants.isEmpty ? nil : grants
        try save(everything)
        return grants
    }

    private func load() throws -> [String: DeckGrants] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        return try JSONDecoder().decode([String: DeckGrants].self, from: Data(contentsOf: fileURL))
    }

    private func save(_ everything: [String: DeckGrants]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(everything).write(to: fileURL, options: .atomic)
    }
}
