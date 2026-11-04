import Foundation

/// An opened deck: the file's exact bytes, its decoded text, and what the
/// adapters found. The HTML file is the source of truth; Cue never stores
/// slides in its own format.
public struct DeckDocument: Sendable {
    public let fileURL: URL
    /// The bytes as read, so an unchanged save is byte-identical.
    public let originalData: Data
    public let encoding: String.Encoding
    /// The current source text. Edits replace this; `originalData` stays.
    public private(set) var source: String
    public private(set) var structure: DeckStructure
    /// The text as decoded on open. Compared as text, not bytes, because
    /// decoding drops a byte-order mark that re-encoding wouldn't restore.
    private let originalSource: String

    public init(contentsOf url: URL, registry: AdapterRegistry = .standard) throws {
        let data = try Data(contentsOf: url)
        let (text, encoding) = try SourceDecoding.decode(data)
        fileURL = url
        originalData = data
        self.encoding = encoding
        source = text
        originalSource = text
        structure = try Self.analyse(text, registry: registry)
    }

    public var isModified: Bool {
        source != originalSource
    }

    /// The folder Cue serves the deck from; file access stops here.
    public var folderURL: URL { fileURL.deletingLastPathComponent() }

    /// `deck.cue.json` beside `deck.html`.
    public var sidecarURL: URL {
        fileURL.deletingPathExtension().appendingPathExtension("cue.json")
    }

    /// Replaces the source text and re-runs the adapters.
    public mutating func replaceSource(_ text: String, registry: AdapterRegistry = .standard) throws {
        structure = try Self.analyse(text, registry: registry)
        source = text
    }

    /// Writes the deck. When nothing changed, the original bytes go back out
    /// untouched (no re-encoding, no normalised line endings).
    public func save(to url: URL? = nil) throws {
        let target = url ?? fileURL
        let data = isModified ? source.data(using: encoding) : originalData
        guard let data else { throw DeckDocumentError.unencodable }
        try data.write(to: target, options: .atomic)
    }

    private static func analyse(_ text: String, registry: AdapterRegistry) throws -> DeckStructure {
        let root = try HTMLParser().parse(text)
        return registry.structure(for: AdapterInput(root: root, source: text))
    }
}

public enum DeckDocumentError: Error, Equatable {
    case undecodable
    case unencodable
}
