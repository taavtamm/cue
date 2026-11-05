import Foundation

/// The live web embeds on a slide, for Claude to read and rewrite.
public struct DeckEmbed: Sendable, Equatable, Codable {
    /// The embed's id (Claude Design decks) or `iframe-<n>`.
    public let id: String
    /// The HTML it runs in its sandbox.
    public let html: String

    public init(id: String, html: String) {
        self.id = id
        self.html = html
    }
}

extension DeckDocument {
    public func embeds(onSlide slide: Int) -> [DeckEmbed] {
        guard structure.slides.indices.contains(slide) else { return [] }
        if structure.adapter == .claudeDesign, let motion = deckMotion {
            let slides = motion["slides"] as? [[String: Any]] ?? []
            guard slides.indices.contains(slide) else { return [] }
            return (slides[slide]["embeds"] as? [[String: Any]] ?? []).compactMap { entry in
                guard let id = entry["id"] as? String else { return nil }
                return DeckEmbed(id: id, html: entry["srcdoc"] as? String ?? "")
            }
        }
        let path = structure.slides[slide].elementPath
        let frames = sourceMap.elements.filter {
            $0.tag == "iframe" && $0.attributes["srcdoc"] != nil && $0.path.starts(with: path) && $0.path != path
        }
        return frames.enumerated().map { DeckEmbed(id: "iframe-\($0.offset + 1)", html: $0.element.attributes["srcdoc"] ?? "") }
    }

    /// The slide's transition: from deck-motion, or `data-cue-transition`.
    public func transition(ofSlide slide: Int) -> String? {
        if structure.adapter == .claudeDesign, let motion = deckMotion {
            let slides = motion["slides"] as? [[String: Any]] ?? []
            return slides.indices.contains(slide) ? slides[slide]["transition"] as? String : nil
        }
        guard structure.slides.indices.contains(slide) else { return nil }
        return sourceMap.element(at: structure.slides[slide].elementPath)?.attributes["data-cue-transition"]
    }

    private var deckMotion: [String: Any]? {
        guard let script = sourceMap.elements.first(where: { $0.tag == "script" && $0.attributes["id"] == "deck-motion" }),
              let inner = script.innerRange else { return nil }
        let json = (source as NSString).substring(with: NSRange(location: inner.start, length: inner.length))
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
    }
}
