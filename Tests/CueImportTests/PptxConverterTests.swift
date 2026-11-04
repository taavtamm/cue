import CueCore
import Foundation
import Testing
@testable import CueImport

@Suite("PowerPoint conversion")
struct PptxConverterTests {
    func convert(_ builder: PptxBuilder) throws -> (ImportedDeck, String, ImportReport) {
        var report = ImportReport(sourceName: "t.pptx", route: "PowerPoint")
        let assets = AssetStore(folderName: "t assets")
        let deck = try PptxConverter().convert(try ZipArchive(data: builder.data()), title: "T", assets: assets,
                                               report: &report)
        return (deck, DeckHTMLWriter.html(for: deck, importedFrom: "t.pptx"), report)
    }

    static func run(_ text: String, _ props: String = "") -> String {
        "<a:r><a:rPr \(props)/><a:t>\(text)</a:t></a:r>"
    }

    @Test func usesSlideSizeAndPresentationOrder() throws {
        var builder = PptxBuilder()
        builder.slides = ["First", "Second", "Third"].map { title in
            .init(shapes: PptxBuilder.textBox(id: 2, x: 0, y: 0, cx: 914_400, cy: 914_400, paragraphs: "<a:p>\(Self.run(title))</a:p>"))
        }
        builder.order = [3, 1, 2]
        let (deck, html, _) = try convert(builder)
        #expect(deck.canvas == CanvasSize(width: 1280, height: 720))
        let positions = ["Third", "First", "Second"].compactMap { html.range(of: ">\($0)<")?.lowerBound }
        #expect(positions.count == 3 && positions == positions.sorted())
    }

    @Test func carriesTextStyles() throws {
        var builder = PptxBuilder()
        let paragraph = "<a:p><a:pPr algn=\"ctr\"/>"
            + Self.run("Bold", "sz=\"3600\" b=\"1\"") + Self.run("Italic", "i=\"1\" u=\"sng\"")
            + "<a:r><a:rPr><a:solidFill><a:schemeClr val=\"accent1\"><a:lumMod val=\"50000\"/></a:schemeClr></a:solidFill>"
            + "<a:latin typeface=\"+mj-lt\"/></a:rPr><a:t>Themed</a:t></a:r></a:p>"
        builder.slides = [.init(shapes: PptxBuilder.textBox(id: 2, x: 914_400, y: 914_400, cx: 4_572_000, cy: 914_400,
                                                            paragraphs: paragraph))]
        let (deck, html, _) = try convert(builder)
        let box = try #require(deck.slides[0].elements.first)
        #expect(box.frame == Rect(x: 96, y: 96, width: 480, height: 96))
        #expect(html.contains("text-align: center"))
        #expect(html.contains("font-size: 48px; font-family: &quot;Helvetica&quot;"))
        #expect(html.contains("font-weight: 700"))
        #expect(html.contains("font-style: italic") && html.contains("text-decoration: underline"))
        #expect(html.contains("font-family: &quot;Georgia&quot;"))
        // accent1 #4F81BD at 50% luminance.
        #expect(html.contains("color: #254061"))
    }

    @Test func placeholdersInheritPositionAndMasterTitleStyle() throws {
        var builder = PptxBuilder()
        builder.layoutShapes = """
            <p:sp><p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
            <p:spPr><a:xfrm><a:off x="952500" y="476250"/><a:ext cx="9525000" cy="952500"/></a:xfrm></p:spPr>
            <p:txBody><a:bodyPr anchor="b"/><a:lstStyle/><a:p><a:r><a:t>Click to add title</a:t></a:r></a:p></p:txBody></p:sp>
            """
        builder.slides = [.init(shapes: """
            <p:sp><p:nvSpPr><p:cNvPr id="5" name="Title 1"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
            <p:spPr/><p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Real title</a:t></a:r></a:p></p:txBody></p:sp>
            """)]
        let (deck, html, _) = try convert(builder)
        #expect(deck.slides[0].label == "Real title")
        #expect(deck.slides[0].elements.count == 1, "layout prompts are not drawn")
        #expect(deck.slides[0].elements[0].frame == Rect(x: 100, y: 50, width: 1000, height: 100))
        #expect(html.contains("justify-content: flex-end"))
        #expect(html.contains("font-size: 58.67px"), "44 pt from the master title style")
        #expect(!html.contains("Click to add title"))
    }

    @Test func bodyPlaceholdersGetMasterBullets() throws {
        var builder = PptxBuilder()
        builder.slides = [.init(shapes: """
            <p:sp><p:nvSpPr><p:cNvPr id="3" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
            <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="4572000" cy="2286000"/></a:xfrm></p:spPr>
            <p:txBody><a:bodyPr/><a:lstStyle/><a:p>\(Self.run("One"))</a:p><a:p>\(Self.run("Two"))</a:p></p:txBody></p:sp>
            """)]
        let (_, html, _) = try convert(builder)
        #expect(html.components(separatedBy: ">•</span>").count == 3)
        #expect(html.contains("padding-left: 24px; text-indent: -24px"))
    }
}
