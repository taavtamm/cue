// swiftlint:disable line_length
// Office XML fixtures read best as one element per line.

import Foundation

/// Builds minimal but valid .pptx packages for tests. Slides are given as
/// `spTree` inner XML; layout and master can carry placeholders.
struct PptxBuilder {
    struct Slide {
        var shapes: String
        var notes: String?
        var timing: String?
        var background: String?
        var images: [String: Data] = [:]   // relationship id → PNG
    }

    var slides: [Slide] = []
    /// Shapes on the layout (placeholders define positions for slide placeholders).
    var layoutShapes = ""
    var masterShapes = ""
    var masterTitleStyle = #"<a:lvl1pPr><a:defRPr sz="4400"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill></a:defRPr></a:lvl1pPr>"#
    var masterBackground = #"<p:bg><p:bgPr><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></p:bgPr></p:bg>"#
    /// Slide order in presentation.xml, as slide file numbers (1-based). Defaults to file order.
    var order: [Int]?
    var size = (cx: 12_192_000, cy: 6_858_000)

    static let ns = #"xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" "#
        + #"xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" "#
        + #"xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main""#
    static let relNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

    func data() -> Data {
        var zip = ZipWriter()
        zip.add("[Content_Types].xml", #"<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>"#)
        zip.add("_rels/.rels", rels([("rId1", "officeDocument", "ppt/presentation.xml")]))
        let ids = (order ?? Array(1...slides.count)).enumerated().map { index, file in
            "<p:sldId id=\"\(256 + index)\" r:id=\"rIdS\(file)\"/>"
        }.joined()
        zip.add("ppt/presentation.xml", """
            <p:presentation \(Self.ns)><p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rIdM"/></p:sldMasterIdLst>
            <p:sldIdLst>\(ids)</p:sldIdLst><p:sldSz cx="\(size.cx)" cy="\(size.cy)"/>
            <p:defaultTextStyle><a:lvl1pPr><a:defRPr sz="1800"><a:solidFill><a:schemeClr val="tx1"/></a:solidFill></a:defRPr></a:lvl1pPr></p:defaultTextStyle>
            </p:presentation>
            """)
        var presentationRels = [("rIdM", "slideMaster", "slideMasters/slideMaster1.xml")]
        presentationRels += slides.indices.map { ("rIdS\($0 + 1)", "slide", "slides/slide\($0 + 1).xml") }
        zip.add("ppt/_rels/presentation.xml.rels", rels(presentationRels))
        zip.add("ppt/theme/theme1.xml", Self.theme)
        zip.add("ppt/slideMasters/slideMaster1.xml", """
            <p:sldMaster \(Self.ns)><p:cSld>\(masterBackground)<p:spTree>\(masterShapes)</p:spTree></p:cSld>
            <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
            <p:txStyles><p:titleStyle>\(masterTitleStyle)</p:titleStyle><p:bodyStyle><a:lvl1pPr marL="228600" indent="-228600"><a:buChar char="•"/><a:defRPr sz="2800"/></a:lvl1pPr></p:bodyStyle><p:otherStyle/></p:txStyles>
            </p:sldMaster>
            """)
        zip.add("ppt/slideMasters/_rels/slideMaster1.xml.rels", rels([("rId1", "theme", "../theme/theme1.xml")]))
        zip.add("ppt/slideLayouts/slideLayout1.xml", "<p:sldLayout \(Self.ns)><p:cSld><p:spTree>\(layoutShapes)</p:spTree></p:cSld></p:sldLayout>")
        zip.add("ppt/slideLayouts/_rels/slideLayout1.xml.rels", rels([("rId1", "slideMaster", "../slideMasters/slideMaster1.xml")]))
        for (index, slide) in slides.enumerated() {
            let number = index + 1
            let background = slide.background.map { "<p:bg>\($0)</p:bg>" } ?? ""
            zip.add("ppt/slides/slide\(number).xml", """
                <p:sld \(Self.ns)><p:cSld>\(background)<p:spTree>\(slide.shapes)</p:spTree></p:cSld>\(slide.timing ?? "")</p:sld>
                """)
            var slideRels = [("rIdL", "slideLayout", "../slideLayouts/slideLayout1.xml")]
            for (id, png) in slide.images.sorted(by: { $0.key < $1.key }) {
                let path = "media/s\(number)-\(id).png"
                zip.add("ppt/\(path)", png)
                slideRels.append((id, "image", "../\(path)"))
            }
            if let notes = slide.notes {
                slideRels.append(("rIdN", "notesSlide", "../notesSlides/notesSlide\(number).xml"))
                zip.add("ppt/notesSlides/notesSlide\(number).xml", """
                    <p:notes \(Self.ns)><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Notes"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr><p:spPr/><p:txBody><a:bodyPr/>\(notes.split(separator: "\n").map { "<a:p><a:r><a:t>\($0)</a:t></a:r></a:p>" }.joined())</p:txBody></p:sp></p:spTree></p:cSld></p:notes>
                    """)
            }
            zip.add("ppt/slides/_rels/slide\(number).xml.rels", rels(slideRels))
        }
        return zip.data()
    }

    private func rels(_ items: [(String, String, String)]) -> String {
        let body = items.map { "<Relationship Id=\"\($0.0)\" Type=\"\(Self.relNS)/\($0.1)\" Target=\"\($0.2)\"/>" }.joined()
        return #"<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#
            + body + "</Relationships>"
    }

    static let theme = """
        <a:theme \(ns) name="Test"><a:themeElements><a:clrScheme name="Test">
        <a:dk1><a:srgbClr val="111111"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>
        <a:dk2><a:srgbClr val="1F497D"/></a:dk2><a:lt2><a:srgbClr val="EEECE1"/></a:lt2>
        <a:accent1><a:srgbClr val="4F81BD"/></a:accent1><a:accent2><a:srgbClr val="C0504D"/></a:accent2>
        <a:accent3><a:srgbClr val="9BBB59"/></a:accent3><a:accent4><a:srgbClr val="8064A2"/></a:accent4>
        <a:accent5><a:srgbClr val="4BACC6"/></a:accent5><a:accent6><a:srgbClr val="F79646"/></a:accent6>
        <a:hlink><a:srgbClr val="0000FF"/></a:hlink><a:folHlink><a:srgbClr val="800080"/></a:folHlink></a:clrScheme>
        <a:fontScheme name="Test"><a:majorFont><a:latin typeface="Georgia"/></a:majorFont><a:minorFont><a:latin typeface="Helvetica"/></a:minorFont></a:fontScheme>
        <a:fmtScheme name="Test"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>
        </a:themeElements></a:theme>
        """

    /// A text box shape at EMU position.
    static func textBox(id: Int, x: Int, y: Int, cx: Int, cy: Int, paragraphs: String, extra: String = "") -> String {
        """
        <p:sp><p:nvSpPr><p:cNvPr id="\(id)" name="Text \(id)"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
        <p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom>\(extra)</p:spPr>
        <p:txBody><a:bodyPr/><a:lstStyle/>\(paragraphs)</p:txBody></p:sp>
        """
    }
}
