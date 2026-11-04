import CueCore
import Foundation

/// OpenDocument presentations (.odp) without Keynote: text, pictures and
/// notes come across with simplified formatting.
struct ODPConverter: DeckImporter {
    func makeDeck(from url: URL, assets: AssetStore, report: inout ImportReport) async throws -> ImportedDeck {
        let zip: ZipArchive
        let content: XNode
        do {
            zip = try ZipArchive(contentsOf: url)
            content = try XMLTreeParser.parse(try zip.data(for: "content.xml"), name: "content.xml")
        } catch {
            throw ImportError.damaged(error.localizedDescription)
        }
        let styles = ODPTextStyles(content.child("automatic-styles"))
        let canvas = Self.pageSize(zip) ?? CanvasSize(width: 1280, height: 720)
        var deck = ImportedDeck(title: url.deletingPathExtension().lastPathComponent, canvas: canvas)
        let pages = content.child("body")?.child("presentation")?.children("page") ?? []
        for (index, page) in pages.enumerated() {
            var slide = ImportedSlide(label: page["name"].flatMap { $0.hasPrefix("page") ? nil : $0 } ?? "")
            for node in page.children where node.name != "notes" {
                guard let element = element(node, styles: styles, zip: zip, assets: assets) else { continue }
                if node["class"] == "title", slide.label.isEmpty { slide.label = ODPText.plain(node) }
                slide.elements.append(element)
            }
            slide.notes = page.child("notes").map(ODPText.plain) ?? ""
            if slide.label.isEmpty { slide.label = "Slide \(index + 1)" }
            deck.slides.append(slide)
        }
        report.note("OpenDocument import keeps text, pictures and notes; formatting is simplified.")
        return deck
    }

    private func element(_ node: XNode, styles: ODPTextStyles, zip: ZipArchive, assets: AssetStore) -> ImportedElement? {
        guard ["frame", "custom-shape", "rect", "ellipse"].contains(node.name) else { return nil }
        let frame = Rect(
            x: ODPLength.pixels(node["x"]), y: ODPLength.pixels(node["y"]),
            width: ODPLength.pixels(node["width"]), height: ODPLength.pixels(node["height"])
        )
        if let image = node.child("image"), let href = image["href"], let data = try? zip.data(for: href) {
            let source = assets.add(data, key: href, preferredName: (href as NSString).lastPathComponent)
            return ImportedElement(name: node["name"] ?? "", frame: frame, content: .image(source: source, crop: nil, alt: ""))
        }
        let container = node.child("text-box") ?? node
        let html = ODPText.html(container, styles: styles)
        guard !html.isEmpty else { return nil }
        var element = ImportedElement(name: node["name"] ?? "", frame: frame, content: .html(html))
        element.isTextBox = true
        return element
    }

    /// The first page layout in styles.xml.
    static func pageSize(_ zip: ZipArchive) -> CanvasSize? {
        guard let data = try? zip.data(for: "styles.xml"), let styles = try? XMLTreeParser.parse(data),
              let layout = styles.descendants.first(where: { $0.name == "page-layout-properties" }),
              let width = layout["page-width"], let height = layout["page-height"] else { return nil }
        return CanvasSize(width: ODPLength.pixels(width).rounded(), height: ODPLength.pixels(height).rounded())
    }
}

/// ODF lengths ("2.5cm", "12pt", "1in", "10mm") in CSS pixels.
enum ODPLength {
    static func pixels(_ value: String?) -> Double {
        guard let value else { return 0 }
        let units: [(String, Double)] = [("cm", 96 / 2.54), ("mm", 96 / 25.4), ("in", 96), ("pt", 4.0 / 3), ("px", 1)]
        for (suffix, factor) in units where value.hasSuffix(suffix) {
            return (Double(value.dropLast(suffix.count)) ?? 0) * factor
        }
        return Double(value) ?? 0
    }
}
