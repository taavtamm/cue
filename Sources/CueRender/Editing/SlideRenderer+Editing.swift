import CueCore
import Foundation

/// The editing API the editor and the MCP server use on any open surface:
/// map clicks to source, apply edits live, explain where a style comes from.
extension SlideRenderer {
    /// Tags the live DOM with the source's `data-cue-id`s (in memory only).
    @discardableResult
    public func mapSourceElements(_ manifest: [LiveElement]) async throws -> LiveMappingReport {
        let pairs = manifest.map { [$0.cueID, $0.tag] }
        let report = LiveMappingReport(try await callInBridge(
            "return window.__cue.sourceMap.assign(manifest)", arguments: ["manifest": pairs]
        ))
        lastMapping = report
        return report
    }

    /// The source element under a point in this surface (AppKit coordinates).
    public func element(at point: CGPoint) async throws -> LiveHit? {
        let css = CGPoint(x: point.x, y: bounds.height - point.y) // The page's origin is top-left.
        let value = try await callInBridge(
            "return window.__cue.sourceMap.at(x, y)", arguments: ["x": css.x, "y": css.y]
        )
        guard let hit = value as? [String: Any], let cueID = hit["cueID"] as? String,
              let rect = hit["rect"] as? [String: Double]
        else { return nil }
        let height = rect["height"] ?? 0
        let frame = CGRect(x: rect["x"] ?? 0, y: bounds.height - (rect["y"] ?? 0) - height,
                           width: rect["width"] ?? 0, height: height)
        return LiveHit(cueID: cueID, tag: hit["tag"] as? String ?? "", frame: frame)
    }

    /// Where `property`'s value on an element comes from.
    public func styleSource(cueID: String, property: String) async throws -> StyleProvenance? {
        StyleProvenance(try await callInBridge(
            "return window.__cue.styleSource.source(id, property)", arguments: ["id": cueID, "property": property]
        ))
    }

    /// Brings this surface up to date with an edited document: in place
    /// when the edit allows it, otherwise a reload at the same position.
    public func applyLive(_ update: LiveUpdate, from document: DeckDocument) async throws {
        switch update {
        case .none:
            return
        case .inPlace(let changes, let remap):
            if sourceManifest != nil { sourceManifest = document.liveManifest }
            let applied = try await apply(changes)
            if remap, let manifest = sourceManifest { try await mapSourceElements(manifest) }
            if applied < changes.count { try await reload(from: document) } // An element wasn't live: be exact.
        case .reload:
            try await reload(from: document)
        }
    }

    /// Applies DOM changes; returns how many found their element.
    @discardableResult
    public func apply(_ changes: [DOMChange]) async throws -> Int {
        let wire = changes.map(Self.wire)
        return try await callInBridge("return window.__cue.domEdits.applyAll(changes)", arguments: ["changes": wire])
            as? Int ?? 0
    }

    private func reload(from document: DeckDocument) async throws {
        if sourceManifest != nil { sourceManifest = document.liveManifest }
        var next = source ?? DeckSource(document: document)
        next.sourceText = document.source
        next.structure = document.structure
        let slide = min(position.slide, max(0, document.structure.slides.count - 1))
        try await load(next, at: ShowPosition(slide: slide, build: 0))
    }

    private static func wire(_ change: DOMChange) -> [String: Any] {
        switch change {
        case .setInnerHTML(let cueID, let html):
            ["type": "setInnerHTML", "cueID": cueID, "html": html]
        case .setAttribute(let cueID, let name, let value):
            ["type": "setAttribute", "cueID": cueID, "name": name, "value": value ?? NSNull()]
        case .setOverrides(let css):
            ["type": "setOverrides", "css": css]
        case .insertHTML(let parentCueID, let html):
            ["type": "insertHTML", "parentCueID": parentCueID, "html": html]
        case .remove(let cueID):
            ["type": "remove", "cueID": cueID]
        }
    }
}
