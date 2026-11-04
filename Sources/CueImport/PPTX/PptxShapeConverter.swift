import Foundation

/// Converts a shape tree (`spTree` or `grpSp`) into positioned elements.
struct PptxShapeConverter {
    let context: PptxContext
    /// Placeholders are drawn only on slides; on layouts and masters they're prompts.
    let drawsPlaceholders: Bool
    /// Click builds by shape id, from the slide's timing.
    var builds: [String: (step: Int, effect: String)] = [:]

    func convert(_ tree: XNode, space: PptxSpace) -> [ImportedElement] {
        tree.children.flatMap { convert(node: $0, space: space) }
    }

    private func convert(node: XNode, space: PptxSpace) -> [ImportedElement] {
        var element: ImportedElement?
        switch node.name {
        case "sp": element = shape(node, space: space)
        case "pic": element = picture(node, space: space)
        case "grpSp": element = group(node, space: space)
        case "cxnSp": element = connector(node, space: space)
        case "graphicFrame": element = graphicFrame(node, space: space)
        case "AlternateContent":
            let branch = node.child("Fallback") ?? node.child("Choice")
            return branch.map { convert($0, space: space) } ?? []
        case "contentPart": context.note("Ink drawings aren't imported")
        default: break
        }
        guard var element else { return [] }
        if let id = Self.shapeID(node), let build = builds[id] { element.build = build }
        return [element]
    }

    static func shapeID(_ node: XNode) -> String? {
        node.children.first { $0.name.hasPrefix("nv") }?.child("cNvPr")?["id"]
    }

    static func shapeName(_ node: XNode) -> String {
        node.children.first { $0.name.hasPrefix("nv") }?.child("cNvPr")?["name"] ?? ""
    }

    // MARK: Position

    /// The shape's `xfrm`, else the one its layout or master placeholder has.
    func transform(_ node: XNode, properties: XNode?) -> XNode? {
        if let xfrm = properties?.child("xfrm") ?? node.child("xfrm") { return xfrm }
        guard let ph = PptxPlaceholders.placeholder(of: node) else { return nil }
        let inherited = context.placeholders.inherited(for: ph)
        return [inherited.layout, inherited.master].lazy.compactMap { $0?.child("spPr")?.child("xfrm") }.first
    }

    func place(_ element: inout ImportedElement, xfrm: XNode?, space: PptxSpace) {
        guard let xfrm else { return }
        let off = xfrm.child("off"), ext = xfrm.child("ext")
        element.frame = space.rect(
            offX: off?.double("x") ?? 0, offY: off?.double("y") ?? 0,
            width: ext?.double("cx") ?? 0, height: ext?.double("cy") ?? 0
        )
        element.rotation = PptxUnits.degrees(xfrm.double("rot") ?? 0)
        element.flipH = xfrm.bool("flipH") ?? false
        element.flipV = xfrm.bool("flipV") ?? false
    }

    // MARK: Groups and connectors

    private func group(_ node: XNode, space: PptxSpace) -> ImportedElement? {
        guard let xfrm = node.child("grpSpPr")?.child("xfrm") else {
            let children = convert(node, space: space)
            return children.isEmpty ? nil : ImportedElement(name: Self.shapeName(node), frame: .zero, content: .group(children))
        }
        var element = ImportedElement(name: Self.shapeName(node), frame: .zero, content: .empty)
        place(&element, xfrm: xfrm, space: space)
        let children = convert(node, space: space.child(of: xfrm))
        guard !children.isEmpty else { return nil }
        element.content = .group(children)
        return element
    }

    private func connector(_ node: XNode, space: PptxSpace) -> ImportedElement? {
        let properties = node.child("spPr")
        var element = ImportedElement(name: Self.shapeName(node), frame: .zero, content: .empty)
        place(&element, xfrm: transform(node, properties: properties), space: space)
        let line = PptxLine.from(properties, styleRef: node.child("style")?.child("lnRef"), context)
        guard line?.color != nil else { return nil }
        let arrow = (properties?.child("ln")?.child("tailEnd")?["type"]).map { $0 != "none" } ?? false
        let svg = PptxGeometry.lineSVG(frame: element.frame, flipH: element.flipH, flipV: element.flipV,
                                       line: line, arrowAtEnd: arrow)
        element.content = .html(svg)
        element.flipH = false
        element.flipV = false
        element.style.set("overflow", "visible")
        return element
    }
}

extension Rect {
    static let zero = Rect(x: 0, y: 0, width: 0, height: 0)
}
