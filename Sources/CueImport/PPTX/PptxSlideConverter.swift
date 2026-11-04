import Foundation

/// One slide: master and layout shapes behind, then the slide's own,
/// with background, notes, label and builds.
struct PptxSlideConverter {
    let package: PptxPackage
    let presentation: PptxPresentationInfo
    let assets: AssetStore
    let notes: ImportNotes
    let fonts: FontCatalog

    func convert(part: String, number: Int) throws -> ImportedSlide {
        let slide = try package.xml(part)
        let layoutPart = package.related(part, type: "slideLayout")
        let masterPart = layoutPart.flatMap { package.related($0, type: "slideMaster") }
        let layout = layoutPart.flatMap { try? package.xml($0) }
        let master = masterPart.flatMap { try? package.xml($0) }
        let themePart = masterPart.flatMap { package.related($0, type: "theme") }
        let theme = themePart.flatMap { try? package.xml($0) }.map(PptxTheme.init) ?? PptxTheme()

        var map = PptxColors.defaultMap
        for (key, value) in master?.child("clrMap")?.attributes ?? [:] { map[key] = value }
        for (key, value) in slide.child("clrMapOvr")?.child("overrideClrMapping")?.attributes ?? [:] { map[key] = value }

        let context = PptxContext(
            package: package, part: part, theme: theme, colors: PptxColors(scheme: theme.colors, map: map),
            assets: assets, notes: notes, fonts: fonts, slideNumber: number,
            placeholders: PptxPlaceholders(
                layoutTree: layout?.at("cSld", "spTree"), masterTree: master?.at("cSld", "spTree"),
                masterTextStyles: master?.child("txStyles")
            ),
            defaultTextStyle: presentation.defaultTextStyle
        )

        var elements: [ImportedElement] = []
        let showsMaster = slide.bool("showMasterSp") != false && layout?.bool("showMasterSp") != false
        if showsMaster, let masterPart, let tree = master?.at("cSld", "spTree") {
            elements += PptxShapeConverter(context: context.drawing(masterPart), drawsPlaceholders: false)
                .convert(tree, space: .slide)
        }
        if slide.bool("showMasterSp") != false, let layoutPart, let tree = layout?.at("cSld", "spTree") {
            elements += PptxShapeConverter(context: context.drawing(layoutPart), drawsPlaceholders: false)
                .convert(tree, space: .slide)
        }
        var converter = PptxShapeConverter(context: context, drawsPlaceholders: true)
        converter.builds = PptxTiming.builds(in: slide, context)
        let tree = slide.at("cSld", "spTree")
        if let tree { elements += converter.convert(tree, space: .slide) }

        let title = tree?.descendants.lazy.compactMap(PptxShapeConverter.titleText(of:)).first
        return ImportedSlide(
            label: title ?? slide.child("cSld")?["name"].flatMap { $0.hasPrefix("Slide ") ? nil : $0 } ?? "",
            notes: speakerNotes(for: part),
            background: background([(part, slide), (layoutPart, layout), (masterPart, master)], context),
            elements: elements
        )
    }

    /// The first of slide, layout, master that sets a background.
    private func background(_ parts: [(String?, XNode?)], _ context: PptxContext) -> String? {
        for case let (part?, node?) in parts {
            guard let bg = node.child("cSld")?.child("bg") else { continue }
            let drawing = context.drawing(part)
            if let properties = bg.child("bgPr"), let fill = PptxFill.background(in: properties, drawing) { return fill }
            if let ref = bg.child("bgRef"), let fill = PptxFill.themeFill(ref, list: drawing.theme.fillStyles, drawing) {
                return fill
            }
        }
        return nil
    }

    /// The notes page's body placeholder text.
    private func speakerNotes(for part: String) -> String {
        guard let notesPart = package.related(part, type: "notesSlide"),
              let page = try? package.xml(notesPart) else { return "" }
        let bodies = page.descendants.filter { node in
            node.name == "sp" && PptxPlaceholders.placeholder(of: node)?["type"] == "body"
        }
        let paragraphs = bodies.flatMap { $0.child("txBody")?.children("p") ?? [] }.map { paragraph in
            paragraph.children.map { child in
                child.name == "br" ? "\n" : child.descendants.filter { $0.name == "t" }.map(\.text).joined()
            }.joined()
        }
        return paragraphs.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
