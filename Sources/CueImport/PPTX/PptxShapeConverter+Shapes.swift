import Foundation

extension PptxShapeConverter {
    /// `p:sp`: a box with optional fill, outline, geometry and text.
    func shape(_ node: XNode, space: PptxSpace) -> ImportedElement? {
        let ph = PptxPlaceholders.placeholder(of: node)
        if ph != nil && !drawsPlaceholders { return nil }
        let inherited = ph.map { context.placeholders.inherited(for: $0) } ?? .init()
        let properties = node.child("spPr")
        let style = node.child("style")

        var element = ImportedElement(name: Self.shapeName(node), frame: .zero, content: .empty)
        place(&element, xfrm: transform(node, properties: properties), space: space)
        guard element.frame.width > 0 || element.frame.height > 0 else { return nil }

        var fill = PptxFill.background(in: properties, styleRef: style?.child("fillRef"), context)
        if fill == nil {
            fill = inherited.shapes.reversed().lazy.compactMap { PptxFill.background(in: $0.child("spPr"), context) }.first
        }
        let line = PptxLine.from(properties, styleRef: style?.child("lnRef"), context)

        if let geometry = properties?.child("custGeom") {
            if let svg = PptxCustomGeometry.svg(geometry, fill: fill, line: line, context) {
                element.content = .html(svg)
            }
        } else {
            switch PptxGeometry.shape(properties, frame: element.frame) {
            case .line:
                let svg = PptxGeometry.lineSVG(frame: element.frame, flipH: element.flipH, flipV: element.flipV,
                                               line: line, arrowAtEnd: false)
                element.content = .html(svg)
                return element
            case .box(let radius, let clip):
                applyBox(&element, fill: fill, line: line, radius: radius, clip: clip)
            case .unknown(let name):
                applyBox(&element, fill: fill, line: line, radius: nil, clip: nil)
                context.note("The “\(name)” shape is drawn as a rectangle")
            }
        }

        if let body = node.child("txBody") {
            let chain = textChain(ph: ph, inherited: inherited, style: style)
            let text = PptxTextRenderer.render(body, chain: chain, context)
            if text.hasText {
                var inner = text.html
                if case .html(let svg) = element.content { inner = svg + "<div style=\"position: relative\">\(inner)</div>" }
                element.content = .html(inner)
                element.isTextBox = true
                for (property, value) in text.box.declarations { element.style.set(property, value) }
                element.style.set("overflow", "visible")
            }
        }

        let visible = element.isTextBox || element.content.isDrawn || !element.style.isEmpty
        return visible ? element : nil
    }

    private func applyBox(_ element: inout ImportedElement, fill: String?, line: PptxLine?, radius: String?, clip: String?) {
        if let fill, fill != "transparent" { element.style.set("background", fill) }
        if let border = line?.cssBorder { element.style.set("border", border) }
        element.style.set("border-radius", radius)
        element.style.set("clip-path", clip)
    }

    private func textChain(ph: XNode?, inherited: PptxPlaceholders.Inherited, style: XNode?) -> PptxTextChain {
        var chain = PptxTextChain()
        chain.lists = [ph == nil ? context.defaultTextStyle : context.placeholders.baseListStyle(for: ph)]
        chain.lists += inherited.shapes.map { $0.child("txBody")?.child("lstStyle") }
        chain.bodyProperties = inherited.shapes.map { $0.child("txBody")?.child("bodyPr") }
        if let fontRef = style?.child("fontRef") {
            chain.baseColor = context.colors.color(in: fontRef)
            chain.baseTypeface = fontRef["idx"] == "major" ? context.theme.majorLatin : context.theme.minorLatin
        }
        return chain
    }

    /// The text of a title placeholder, for the slide label.
    static func titleText(of node: XNode) -> String? {
        guard let ph = PptxPlaceholders.placeholder(of: node), PptxPlaceholders.family(ph["type"]) == "title",
              let body = node.child("txBody") else { return nil }
        let text = body.children("p").map { paragraph in
            paragraph.descendants.filter { $0.name == "t" }.map(\.text).joined()
        }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

extension ImportedElement.Content {
    var isDrawn: Bool {
        switch self {
        case .empty: false
        default: true
        }
    }
}
