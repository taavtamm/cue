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
    /// Network hosts the HTML names, found before any of its code runs.
    public private(set) var remoteResources: [RemoteResource]
    /// Every element with its source ranges, rebuilt after each edit.
    public private(set) var sourceMap: SourceMap
    /// The parsed tree the source map and structure came from.
    public private(set) var tree: HTMLNode
    public internal(set) var history = EditHistory()
    /// The text last written to disk, for `isDirty`.
    private var savedSource: String
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
        savedSource = text
        let analysis = try Self.analyse(text, registry: registry)
        (structure, remoteResources) = (analysis.structure, analysis.resources)
        (sourceMap, tree) = (analysis.map, analysis.tree)
    }

    /// The text differs from the file as opened. When false, saving writes the original bytes.
    public var isModified: Bool {
        source != originalSource
    }

    /// There are edits that haven't been saved.
    public var isDirty: Bool { source != savedSource }

    /// The folder Cue serves the deck from; file access stops here.
    public var folderURL: URL { fileURL.deletingLastPathComponent() }

    /// `deck.cue.json` beside `deck.html`.
    public var sidecarURL: URL {
        fileURL.deletingPathExtension().appendingPathExtension("cue.json")
    }

    /// Replaces the source text, re-parses it and re-runs the adapters.
    public mutating func replaceSource(_ text: String, registry: AdapterRegistry = .standard) throws {
        let analysis = try Self.analyse(text, registry: registry)
        (structure, remoteResources) = (analysis.structure, analysis.resources)
        (sourceMap, tree) = (analysis.map, analysis.tree)
        source = text
    }

    /// Writes the deck. When nothing changed, the original bytes go back out
    /// untouched (no re-encoding, no normalised line endings). Edited text is
    /// written in the file's own encoding, keeping its byte-order mark.
    public func save(to url: URL? = nil) throws {
        try encodedData().write(to: url ?? fileURL, options: .atomic)
    }

    /// Marks the current text as saved, after `save()`.
    public mutating func markSaved() {
        savedSource = source
    }

    func encodedData() throws -> Data {
        guard isModified else { return originalData }
        guard let body = source.data(using: Self.bomlessEncoding(encoding)) else { throw DeckDocumentError.unencodable }
        // Some decoders keep the mark as U+FEFF in the text; then it's already in `body`.
        return source.hasPrefix("\u{FEFF}") ? body : Self.byteOrderMark(of: originalData) + body
    }

    /// The original file's byte-order mark, if it had one.
    private static func byteOrderMark(of data: Data) -> Data {
        let marks: [[UInt8]] = [[0xEF, 0xBB, 0xBF], [0xFE, 0xFF], [0xFF, 0xFE]]
        return marks.first { data.starts(with: $0) }.map { Data($0) } ?? Data()
    }

    /// `.utf16` writes its own byte-order mark; the original mark is restored separately.
    private static func bomlessEncoding(_ encoding: String.Encoding) -> String.Encoding {
        encoding == .utf16 ? .utf16LittleEndian : encoding
    }

    private struct Analysis {
        let structure: DeckStructure
        let resources: [RemoteResource]
        let map: SourceMap
        let tree: HTMLNode
    }

    private static func analyse(_ text: String, registry: AdapterRegistry) throws -> Analysis {
        let root = try HTMLParser().parse(text)
        let structure = registry.structure(for: AdapterInput(root: root, source: text))
        return Analysis(
            structure: structure, resources: RemoteResourceScanner.scan(root: root, source: text),
            map: SourceMap(root: root, source: text), tree: root
        )
    }
}

public enum DeckDocumentError: Error, Equatable {
    case undecodable
    case unencodable
}
