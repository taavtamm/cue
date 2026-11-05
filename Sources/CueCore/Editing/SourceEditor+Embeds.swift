import Foundation

/// Live web embeds and slide transitions. Claude Design decks keep both in
/// their `#deck-motion` JSON, patched in place; other decks keep embeds as
/// `<iframe srcdoc>` and transitions as `data-cue-transition` on the slide.
extension SourceEditor {
    static let transitionKinds: Set<String> = ["fade", "push", "magic"]

    func setEmbedHTML(slide: Int, embed: String, html: String) throws -> SourceEdit {
        if let motion = try DeckMotionPatches(editor: self) {
            let embeds: [Range<Int>]
            do { embeds = try motion.spans.elements(at: [.field("slides"), .index(slide), .field("embeds")]) } catch {
                throw EditError.unsupported("slide \(slide + 1) has no live embeds")
            }
            for index in embeds.indices {
                let path: [JSONSpans.Key] = [.field("slides"), .index(slide), .field("embeds"), .index(index)]
                let id = try JSONDecoder().decode(String.self, from: Data(motion.spans.text(try motion.spans.range(at: path + [.field("id")])).utf8))
                guard id == embed else { continue }
                let value = try motion.spans.range(at: path + [.field("srcdoc")])
                let range = SourceRange(start: motion.base + value.lowerBound, end: motion.base + value.upperBound)
                return minimalEdit(replacing: range, with: try ScriptSafeJSON.encode(html))
            }
            throw EditError.unsupported("slide \(slide + 1) has no embed “\(embed)”")
        }
        let frames = try embedFrames(onSlide: slide)
        guard let number = Int(embed.replacingOccurrences(of: "iframe-", with: "")), frames.indices.contains(number - 1) else {
            throw EditError.unsupported("slide \(slide + 1) has no embed “\(embed)” (iframe-1…iframe-\(frames.count))")
        }
        return SourceEdit(try attributePatches(on: frames[number - 1], [("srcdoc", html)]))
    }

    func setTransition(slide: Int, kind: String?) throws -> SourceEdit {
        if let kind, !Self.transitionKinds.contains(kind) {
            throw EditError.unsupported("transition “\(kind)”: use fade, push, magic or none")
        }
        if let motion = try DeckMotionPatches(editor: self) {
            let value = try motion.spans.range(at: [.field("slides"), .index(slide), .field("transition")])
            let range = SourceRange(start: motion.base + value.lowerBound, end: motion.base + value.upperBound)
            return minimalEdit(replacing: range, with: try kind.map { try ScriptSafeJSON.encode($0) } ?? "null")
        }
        return SourceEdit(try attributePatches(on: slideElement(slide), [("data-cue-transition", kind)]))
    }

    /// `<iframe srcdoc>` elements inside a slide, in document order.
    func embedFrames(onSlide slide: Int) throws -> [MappedElement] {
        let element = try slideElement(slide)
        return map.elements.filter {
            $0.tag == "iframe" && $0.attributes["srcdoc"] != nil && $0.path.starts(with: element.path) && $0.path != element.path
        }
    }
}
