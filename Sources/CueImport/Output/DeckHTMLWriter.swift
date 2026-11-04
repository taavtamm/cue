import CueCore
import Foundation

/// Writes an `ImportedDeck` as a readable Cue-convention HTML file:
/// one `<section data-cue-slide>` per slide, one absolutely positioned
/// `div` per element, builds as `data-cue-build`.
public enum DeckHTMLWriter {
    public static func html(for deck: ImportedDeck, importedFrom source: String) -> String {
        let width = css(deck.canvas.width, ""), height = css(deck.canvas.height, "")
        var out = """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="cue:canvas" content="\(width)x\(height)">
            <meta name="cue:imported-from" content="\(HTMLText.attribute(source))">
            <title>\(HTMLText.text(deck.title))</title>
            <style>
              body { margin: 0; padding: 24px 0; background: #1c1c1e; }
              [data-cue-slide] { position: relative; width: \(width)px; height: \(height)px; overflow: hidden;
                margin: 0 auto 24px; background: #fff; }
              .cue-el { position: absolute; box-sizing: border-box; }
              .cue-el > img, .cue-crop > img { display: block; }
              .cue-text { display: flex; flex-direction: column; overflow-wrap: break-word; }
              .cue-el p { margin: 0; white-space: pre-wrap; }
              .cue-table { border-collapse: collapse; width: 100%; height: 100%; table-layout: fixed; }
            </style>
            </head>
            <body>

            """
        for (index, slide) in deck.slides.enumerated() {
            out += section(slide, index: index)
        }
        out += "</body>\n</html>\n"
        return out
    }

    private static func section(_ slide: ImportedSlide, index: Int) -> String {
        var attributes = "data-cue-slide id=\"slide-\(index + 1)\""
        if !slide.label.isEmpty { attributes += " data-label=\"\(HTMLText.attribute(slide.label))\"" }
        if !slide.notes.isEmpty { attributes += " data-cue-notes=\"\(HTMLText.attribute(slide.notes))\"" }
        if let background = slide.background { attributes += " style=\"background: \(HTMLText.attribute(background))\"" }
        var out = "<section \(attributes)>\n"
        for element in slide.elements { out += element_(element, depth: 1) }
        return out + "</section>\n\n"
    }

    private static func element_(_ element: ImportedElement, depth: Int) -> String {
        let indent = String(repeating: "  ", count: depth)
        var style = CSSStyle()
        style.set("left", css(element.frame.x))
        style.set("top", css(element.frame.y))
        style.set("width", css(element.frame.width))
        style.set("height", css(element.frame.height))
        if element.rotation != 0 { style.set("transform", "rotate(\(css(element.rotation, "deg")))") }
        for (property, value) in element.style.declarations { style.set(property, value) }

        let classes = element.isTextBox ? "cue-el cue-text" : "cue-el"
        var attributes = "class=\"\(classes)\""
        if !element.name.isEmpty { attributes += " data-cue-name=\"\(HTMLText.attribute(element.name))\"" }
        if let build = element.build {
            attributes += " data-cue-build=\"\(build.step)\" data-cue-effect=\"\(HTMLText.attribute(build.effect))\""
        }
        attributes += " style=\"\(HTMLText.attribute(style.text))\""

        switch element.content {
        case .empty:
            return "\(indent)<div \(attributes)></div>\n"
        case .html(let inner):
            return "\(indent)<div \(attributes)>\(inner)</div>\n"
        case .image(let source, let crop, let alt):
            let image = imageHTML(source: source, crop: crop, alt: alt, flipH: element.flipH, flipV: element.flipV)
            return "\(indent)<div \(attributes)>\(image)</div>\n"
        case .group(let children):
            var out = "\(indent)<div \(attributes)>\n"
            for child in children { out += element_(child, depth: depth + 1) }
            return out + "\(indent)</div>\n"
        }
    }

    /// A crop is a wrapper with overflow hidden and an enlarged, shifted picture.
    private static func imageHTML(source: String, crop: ImageCrop?, alt: String, flipH: Bool, flipV: Bool) -> String {
        var flip = ""
        if flipH || flipV { flip = "; transform: scale(\(flipH ? -1 : 1), \(flipV ? -1 : 1))" }
        let src = HTMLText.attribute(source), altText = HTMLText.attribute(alt)
        guard let crop, !crop.isEmpty else {
            return "<img src=\"\(src)\" alt=\"\(altText)\" style=\"width: 100%; height: 100%\(flip)\">"
        }
        let visibleW = max(0.01, 1 - crop.left - crop.right), visibleH = max(0.01, 1 - crop.top - crop.bottom)
        let style = "position: absolute; width: \(css(100 / visibleW, "%")); height: \(css(100 / visibleH, "%")); "
            + "left: \(css(-100 * crop.left / visibleW, "%")); top: \(css(-100 * crop.top / visibleH, "%"))\(flip)"
        return "<div class=\"cue-crop\" style=\"position: absolute; inset: 0; overflow: hidden\">"
            + "<img src=\"\(src)\" alt=\"\(altText)\" style=\"\(style)\"></div>"
    }
}
