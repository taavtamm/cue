import CueCore
import Foundation

/// Opens any supported presentation as an HTML deck. HTML opens as is;
/// everything else is converted once into `<Name> (Cue).html` beside it.
/// The original file is never modified.
public struct ImportService: Sendable {
    public struct PreparedDeck: Sendable, Equatable {
        /// The HTML deck to open.
        public let htmlURL: URL
        /// Nil when nothing was converted (HTML, or Cue's existing copy).
        public let report: ImportReport?
        /// Set when Cue's copy from an earlier import was reused.
        public let reusedCopy: ReusedCopy?
    }

    public struct ReusedCopy: Sendable, Equatable {
        /// The original changed after Cue's copy was made: offer to convert again.
        public let originalIsNewer: Bool
    }

    public var keynote: KeynoteExporter
    public var fallbackFolder: URL?

    public init(keynote: KeynoteExporter = KeynoteExporter(), fallbackFolder: URL? = nil) {
        self.keynote = keynote
        self.fallbackFolder = fallbackFolder
    }

    public static let presentationExtensions: Set<String> = ["pptx", "ppt", "key", "odp", "pdf"]

    public static func needsImport(_ url: URL) -> Bool {
        presentationExtensions.contains(url.pathExtension.lowercased())
    }

    /// Returns the deck to open. With `replacingCopy`, converts again over
    /// Cue's earlier copy instead of reusing it.
    public func prepare(_ url: URL, replacingCopy: Bool = false) async throws -> PreparedDeck {
        guard Self.needsImport(url) else { return PreparedDeck(htmlURL: url, report: nil, reusedCopy: nil) }
        let destination = ImportDestination.choose(for: url, fallbackFolder: fallbackFolder)
        if destination.exists && !replacingCopy {
            return PreparedDeck(htmlURL: destination.htmlURL, report: nil,
                                reusedCopy: ReusedCopy(originalIsNewer: Self.isNewer(url, than: destination.htmlURL)))
        }
        return try await convert(url, to: destination)
    }

    private func convert(_ url: URL, to destination: ImportDestination) async throws -> PreparedDeck {
        let ext = url.pathExtension.lowercased()
        let assets = AssetStore(folderName: destination.assetsURL.lastPathComponent)
        var report = ImportReport(sourceName: url.lastPathComponent, route: "")
        if destination.isRelocated { report.outputRelocated = destination.htmlURL.deletingLastPathComponent() }

        let deck: ImportedDeck
        switch ext {
        case "pptx":
            report.route = "PowerPoint"
            deck = try await PptxConverter().makeDeck(from: url, assets: assets, report: &report)
        case "pdf":
            report.route = "PDF"
            deck = try await PDFImporter().makeDeck(from: url, assets: assets, report: &report)
        case "key", "ppt", "odp":
            deck = try await viaKeynoteOrFallback(url, ext: ext, assets: assets, report: &report)
        default:
            throw ImportError.unsupportedType(ext)
        }
        guard !deck.slides.isEmpty else { throw ImportError.empty }
        report.isPresentOnly = deck.isPresentOnly
        let html = DeckHTMLWriter.html(for: deck, importedFrom: url.lastPathComponent)
        try destination.write(html: html, assets: assets)
        return PreparedDeck(htmlURL: destination.htmlURL, report: report, reusedCopy: nil)
    }

    /// Keynote converts to PowerPoint, which Cue then converts. Without
    /// Keynote: .key shows its stored preview, .odp is read natively.
    private func viaKeynoteOrFallback(
        _ url: URL, ext: String, assets: AssetStore, report: inout ImportReport
    ) async throws -> ImportedDeck {
        if keynote.isInstalled {
            report.route = "Keynote → PowerPoint"
            let temporary = try await keynote.exportPowerPoint(from: url)
            defer { try? FileManager.default.removeItem(at: temporary.deletingLastPathComponent()) }
            var deck = try await PptxConverter().makeDeck(from: temporary, assets: assets, report: &report)
            deck.title = url.deletingPathExtension().lastPathComponent
            return deck
        }
        switch ext {
        case "key":
            report.route = "Keynote preview"
            return try await KeynotePreviewImporter().makeDeck(from: url, assets: assets, report: &report)
        case "odp":
            report.route = "OpenDocument"
            return try await ODPConverter().makeDeck(from: url, assets: assets, report: &report)
        default:
            throw ImportError.needsKeynote(ext)
        }
    }

    static func isNewer(_ original: URL, than copy: URL) -> Bool {
        // File attributes, not URL resource values, which a URL caches.
        let date = { (url: URL) in (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date }
        guard let source = date(original), let output = date(copy) else { return false }
        return source > output
    }
}
