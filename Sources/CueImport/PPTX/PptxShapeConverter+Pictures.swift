import Foundation

extension PptxShapeConverter {
    /// `p:pic`: a picture, cropped by `srcRect`. Video and audio show their poster frame.
    func picture(_ node: XNode, space: PptxSpace) -> ImportedElement? {
        if PptxPlaceholders.placeholder(of: node) != nil && !drawsPlaceholders { return nil }
        let properties = node.child("spPr")
        var element = ImportedElement(name: Self.shapeName(node), frame: .zero, content: .empty)
        place(&element, xfrm: transform(node, properties: properties), space: space)

        let media = node.child("nvPicPr")?.child("nvPr")
        if media?.child("videoFile") != nil || media?.child("audioFile") != nil
            || media?.descendants.contains(where: { $0.name == "media" }) == true {
            context.note("Video and audio show as their poster frame")
        }
        guard let blipFill = node.child("blipFill"),
              let source = context.asset(relationship: blipFill.child("blip")?["embed"]) else { return nil }
        let alt = node.child("nvPicPr")?.child("cNvPr")?["descr"] ?? ""
        element.content = .image(source: source, crop: Self.crop(blipFill.child("srcRect")), alt: alt)

        if let amount = blipFill.child("blip")?.child("alphaModFix")?.double("amt") {
            element.style.set("opacity", css(amount / 100_000, ""))
        }
        switch PptxGeometry.shape(properties, frame: element.frame) {
        case .box(let radius, let clip):
            element.style.set("border-radius", radius)
            element.style.set("clip-path", clip)
            if radius != nil { element.style.set("overflow", "hidden") }
        default: break
        }
        if let border = PptxLine.from(properties, styleRef: node.child("style")?.child("lnRef"), context)?.cssBorder {
            element.style.set("border", border)
        }
        return element
    }

    static func crop(_ rect: XNode?) -> ImageCrop? {
        guard let rect else { return nil }
        let crop = ImageCrop(
            left: (rect.double("l") ?? 0) / 100_000, top: (rect.double("t") ?? 0) / 100_000,
            right: (rect.double("r") ?? 0) / 100_000, bottom: (rect.double("b") ?? 0) / 100_000
        )
        return crop.isEmpty ? nil : crop
    }

    /// Tables, charts, SmartArt and embedded objects.
    func graphicFrame(_ node: XNode, space: PptxSpace) -> ImportedElement? {
        if PptxPlaceholders.placeholder(of: node) != nil && !drawsPlaceholders { return nil }
        var element = ImportedElement(name: Self.shapeName(node), frame: .zero, content: .empty)
        place(&element, xfrm: node.child("xfrm") ?? transform(node, properties: nil), space: space)
        guard let data = node.child("graphic")?.child("graphicData") else { return nil }
        let kind = (data["uri"] ?? "").components(separatedBy: "/").last ?? ""

        if let table = data.child("tbl") {
            element.content = .html(PptxTable.html(table, context))
            return element
        }
        if kind == "diagram", let drawn = smartArt(data) {
            element.content = .group(drawn)
            return element
        }
        // Embedded objects and charts with a stored preview picture.
        if let preview = data.descendants.first(where: { $0.name == "pic" }),
           let source = context.asset(relationship: preview.child("blipFill")?.child("blip")?["embed"]) {
            element.content = .image(source: source, crop: nil, alt: element.name)
            context.note(kind == "chart" ? "Charts are shown as pictures" : "Embedded objects are shown as pictures")
            return element
        }
        context.note(kind == "chart" ? "Charts can't be imported yet" : "An embedded object couldn't be imported")
        return nil
    }

    /// SmartArt keeps a pre-drawn copy (`dsp:drawing`), linked from the diagram data part.
    private func smartArt(_ data: XNode) -> [ImportedElement]? {
        let rels = context.package.relationships(of: context.part)
        guard let dataID = data.child("relIds")?["dm"], let dataPart = rels[dataID]?.target,
              let model = try? context.package.xml(dataPart),
              let drawingID = model.first("dataModelExt")?["relId"], let drawingPart = rels[drawingID]?.target,
              let drawing = try? context.package.xml(drawingPart), let tree = drawing.child("spTree")
        else {
            context.note("SmartArt couldn't be imported")
            return nil
        }
        let converter = PptxShapeConverter(context: context.drawing(drawingPart), drawsPlaceholders: false)
        // The pre-drawn shapes are positioned relative to the frame.
        let shapes = converter.convert(tree, space: .slide)
        return shapes.isEmpty ? nil : shapes
    }
}
