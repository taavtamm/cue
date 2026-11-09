import Foundation

extension SourceEditor {
    static let overridesID = "cue-overrides"

    /// Edits a rule in `<style id="cue-overrides">`, creating the block at
    /// the end of `<head>` the first time. The deck's own stylesheets are
    /// never touched, so removing this block undoes every style override.
    func setOverride(selector: String, property: String, value: String?) throws -> (SourceEdit, LivePlan) {
        let selector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
        let property = property.trimmingCharacters(in: .whitespaces).lowercased()
        // `<` could close the style block (`</style>`); selectors never need it.
        guard !selector.isEmpty, !selector.contains(where: { "{}<".contains($0) }) else {
            throw EditError.unsupported("selector \(selector)")
        }
        guard StyleDeclarations.isValidProperty(property) else { throw EditError.invalidStyleProperty(property) }
        if let value, value.contains(where: { ";{}\n\r".contains($0) }) || value.contains("</") {
            throw EditError.invalidStyleProperty("\(property): \(value)")
        }
        let value = try value.map { try escaping.verbatim($0.trimmingCharacters(in: .whitespaces)) }
        let selectorText = try escaping.verbatim(selector)

        guard let block = map.elements.first(where: { $0.tag == "style" && $0.attributes["id"] == Self.overridesID }),
              let inner = block.innerRange
        else {
            guard let value else { return (SourceEdit([]), .overrides(created: false)) }
            return (try createOverrides(rule: "\(selectorText) { \(property): \(value); }"), .overrides(created: true))
        }
        let css = text.slice(inner)
        let rules = CSSRules(css)
        let base = inner.start
        if let rule = rules.rule(for: selectorText) {
            let body = String(decoding: Array(css.utf16)[rule.body], as: UTF16.self)
            let declarations = StyleDeclarations(body)
            let patches = declarations.sourcePatches(setting: property, to: value, base: base + rule.body.lowerBound)
            return (SourceEdit(patches), .overrides(created: false))
        }
        guard let value else { return (SourceEdit([]), .overrides(created: false)) }
        let indent = text.indentation(ofLineAt: inner.end)
        let newRule = "\(selectorText) { \(property): \(value); }"
        let trailingStart = text.whitespaceStart(before: inner.end)
        return (SourceEdit([.insert(lineEnding + indent + newRule, at: trailingStart)]), .overrides(created: false))
    }

    private func createOverrides(rule: String) throws -> SourceEdit {
        let head = map.elements.first { $0.tag == "head" }
        let offset = head?.endTag?.start ?? head?.startTag?.end
            ?? map.elements.first { $0.tag == "body" }?.startTag?.start ?? 0
        let indent = text.indentation(ofLineAt: offset)
        let block = "<style id=\"\(Self.overridesID)\">\(lineEnding)\(rule)\(lineEnding)</style>"
        return SourceEdit([.insert(block + lineEnding + indent, at: offset)])
    }
}
