import CueCore
import Foundation
import Testing
@testable import CueImport

@Suite("PowerPoint pictures, groups, builds and backgrounds")
struct PptxContentTests {
    let helper = PptxConverterTests()

    @Test func picturesAreStoredAndCropped() throws {
        var builder = PptxBuilder()
        builder.slides = [.init(shapes: """
            <p:pic><p:nvPicPr><p:cNvPr id="4" name="Photo" descr="A red box"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>
            <p:blipFill><a:blip r:embed="rIdImg"/><a:srcRect l="25000" r="25000"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
            <p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="952500" cy="476250"/></a:xfrm><a:prstGeom prst="rect"/></p:spPr></p:pic>
            """, images: ["rIdImg": TestImages.png()])]
        let (deck, html, _) = try helper.convert(builder)
        guard case .image(let source, let crop, let alt) = deck.slides[0].elements[0].content else {
            Issue.record("expected an image")
            return
        }
        #expect(source == "t%20assets/s1-rIdImg.png")
        #expect(crop == ImageCrop(left: 0.25, top: 0, right: 0.25, bottom: 0))
        #expect(alt == "A red box")
        #expect(html.contains("width: 200%") && html.contains("left: -50%"))
    }

    @Test func groupsScaleTheirChildren() throws {
        var builder = PptxBuilder()
        let child = PptxBuilder.textBox(id: 6, x: 1_000_000, y: 1_000_000, cx: 1_905_000, cy: 952_500,
                                        paragraphs: "<a:p>\(PptxConverterTests.run("Inside"))</a:p>")
        builder.slides = [.init(shapes: """
            <p:grpSp><p:nvGrpSpPr><p:cNvPr id="5" name="Group"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
            <p:grpSpPr><a:xfrm><a:off x="952500" y="952500"/><a:ext cx="1905000" cy="952500"/>
            <a:chOff x="1000000" y="1000000"/><a:chExt cx="3810000" cy="1905000"/></a:xfrm></p:grpSpPr>\(child)</p:grpSp>
            """)]
        let (deck, _, _) = try helper.convert(builder)
        let group = deck.slides[0].elements[0]
        #expect(group.frame == Rect(x: 100, y: 100, width: 200, height: 100))
        guard case .group(let children) = group.content else {
            Issue.record("expected a group")
            return
        }
        #expect(children[0].frame == Rect(x: 0, y: 0, width: 100, height: 50))
    }

    @Test func clickSequenceBecomesBuilds() throws {
        var builder = PptxBuilder()
        let boxes = (2...4).map { id in
            PptxBuilder.textBox(id: id, x: 0, y: id * 500_000, cx: 914_400, cy: 400_000,
                                paragraphs: "<a:p>\(PptxConverterTests.run("Item \(id)"))</a:p>")
        }.joined()
        func click(_ id: Int, preset: Int) -> String {
            "<p:par><p:cTn><p:childTnLst><p:par><p:cTn><p:childTnLst><p:par><p:cTn presetID=\"\(preset)\" presetClass=\"entr\" "
                + "nodeType=\"clickEffect\"><p:childTnLst><p:set><p:cBhvr><p:tgtEl><p:spTgt spid=\"\(id)\"/></p:tgtEl>"
                + "</p:cBhvr></p:set></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par>"
        }
        let timing = "<p:timing><p:tnLst><p:par><p:cTn nodeType=\"tmRoot\"><p:childTnLst><p:seq><p:cTn nodeType=\"mainSeq\">"
            + "<p:childTnLst>\(click(3, preset: 10))\(click(4, preset: 1))</p:childTnLst></p:cTn></p:seq></p:childTnLst>"
            + "</p:cTn></p:par></p:tnLst></p:timing>"
        builder.slides = [.init(shapes: boxes, timing: timing)]
        let (deck, html, _) = try helper.convert(builder)
        let builds = deck.slides[0].elements.map { $0.build?.step }
        #expect(builds == [nil, 1, 2])
        #expect(html.contains("data-cue-build=\"1\" data-cue-effect=\"fade\""))
        #expect(html.contains("data-cue-build=\"2\" data-cue-effect=\"appear\""))
    }

    @Test func backgroundsComeFromSlideOrMaster() throws {
        var builder = PptxBuilder()
        let empty = PptxBuilder.textBox(id: 2, x: 0, y: 0, cx: 1, cy: 1, paragraphs: "<a:p>\(PptxConverterTests.run("x"))</a:p>")
        builder.slides = [
            .init(shapes: empty),
            .init(shapes: empty, background: "<p:bgPr><a:gradFill><a:gsLst><a:gs pos=\"0\"><a:srgbClr val=\"000000\"/></a:gs>"
                  + "<a:gs pos=\"100000\"><a:srgbClr val=\"FFFFFF\"/></a:gs></a:gsLst><a:lin ang=\"5400000\"/></a:gradFill></p:bgPr>"),
        ]
        let (deck, _, _) = try helper.convert(builder)
        #expect(deck.slides[0].background == "#ffffff")
        #expect(deck.slides[1].background == "linear-gradient(180deg, #000000 0, #ffffff 100%)")
    }

    @Test func notesComeFromTheNotesPage() throws {
        var builder = PptxBuilder()
        builder.slides = [.init(shapes: "", notes: "Say hello\nThen the demo")]
        let (deck, html, _) = try helper.convert(builder)
        #expect(deck.slides[0].notes == "Say hello\nThen the demo")
        #expect(html.contains("data-cue-notes=\"Say hello\nThen the demo\""))
    }

    @Test func shapesTablesAndUnknownPresets() throws {
        var builder = PptxBuilder()
        builder.slides = [.init(shapes: """
            <p:sp><p:nvSpPr><p:cNvPr id="2" name="Oval"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr>
            <a:xfrm rot="5400000"><a:off x="0" y="0"/><a:ext cx="952500" cy="952500"/></a:xfrm><a:prstGeom prst="ellipse"/>
            <a:solidFill><a:srgbClr val="FF0000"><a:alpha val="50000"/></a:srgbClr></a:solidFill></p:spPr></p:sp>
            <p:sp><p:nvSpPr><p:cNvPr id="3" name="Cloud"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr>
            <a:xfrm><a:off x="0" y="0"/><a:ext cx="952500" cy="952500"/></a:xfrm><a:prstGeom prst="cloud"/>
            <a:solidFill><a:srgbClr val="00FF00"/></a:solidFill></p:spPr></p:sp>
            <p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="4" name="Table"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>
            <p:xfrm><a:off x="0" y="0"/><a:ext cx="1905000" cy="952500"/></p:xfrm><a:graphic>
            <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table"><a:tbl><a:tblGrid><a:gridCol w="952500"/>
            <a:gridCol w="952500"/></a:tblGrid><a:tr h="476250"><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>A1</a:t></a:r></a:p>
            </a:txBody><a:tcPr><a:solidFill><a:srgbClr val="EEEEEE"/></a:solidFill></a:tcPr></a:tc><a:tc><a:txBody><a:bodyPr/>
            <a:p><a:r><a:t>B1</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc></a:tr></a:tbl></a:graphicData></a:graphic></p:graphicFrame>
            """)]
        let (_, html, report) = try helper.convert(builder)
        #expect(html.contains("border-radius: 50%") && html.contains("rgba(255, 0, 0, 0.5)"))
        #expect(html.contains("transform: rotate(90deg)"))
        #expect(html.contains("<table class=\"cue-table\">") && html.contains(">A1<") && html.contains("background: #eeeeee"))
        #expect(report.summaryLines.contains("Slide 1: The “cloud” shape is drawn as a rectangle"))
    }
}
