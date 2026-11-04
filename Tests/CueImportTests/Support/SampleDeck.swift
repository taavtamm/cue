// swiftlint:disable line_length
// Office XML fixtures read best as one element per line.

import Foundation

/// A deck exercising text, bullets, shapes, tables and pictures, for visual checks.
enum SampleDeck {
    static func data() -> Data {
        var builder = PptxBuilder()
        builder.layoutShapes = """
            <p:sp><p:nvSpPr><p:cNvPr id="2" name="Title"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>
            <p:spPr><a:xfrm><a:off x="838200" y="365125"/><a:ext cx="10515600" cy="1325563"/></a:xfrm></p:spPr>
            <p:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:r><a:t>Title</a:t></a:r></a:p></p:txBody></p:sp>
            <p:sp><p:nvSpPr><p:cNvPr id="3" name="Body"/><p:cNvSpPr/><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr>
            <p:spPr><a:xfrm><a:off x="838200" y="1825625"/><a:ext cx="5181600" cy="4351338"/></a:xfrm></p:spPr>
            <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:t>Body</a:t></a:r></a:p></p:txBody></p:sp>
            """
        let bullets = ["Native PowerPoint import", "Text keeps its <b>size</b> & colour", "Bullets hang correctly"]
            .map { "<a:p><a:r><a:rPr lang=\"en-US\"/><a:t>\($0.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;"))</a:t></a:r></a:p>" }
            .joined()
        builder.slides = [.init(shapes: """
            <p:sp><p:nvSpPr><p:cNvPr id="10" name="Title 1"/><p:cNvSpPr/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr><p:spPr/>
            <p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang="en-US"/><a:t>Imported from PowerPoint</a:t></a:r></a:p></p:txBody></p:sp>
            <p:sp><p:nvSpPr><p:cNvPr id="11" name="Content 2"/><p:cNvSpPr/><p:nvPr><p:ph idx="1"/></p:nvPr></p:nvSpPr><p:spPr/>
            <p:txBody><a:bodyPr/><a:lstStyle/>\(bullets)<a:p><a:pPr lvl="1"/><a:r><a:rPr lang="en-US" i="1"><a:solidFill><a:schemeClr val="accent2"/></a:solidFill></a:rPr><a:t>A second-level point in accent 2</a:t></a:r></a:p></p:txBody></p:sp>
            <p:sp><p:nvSpPr><p:cNvPr id="12" name="Rounded"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="6705600" y="1825625"/><a:ext cx="4648200" cy="1371600"/></a:xfrm>
            <a:prstGeom prst="roundRect"><a:avLst/></a:prstGeom><a:solidFill><a:schemeClr val="accent1"/></a:solidFill><a:ln w="19050"><a:solidFill><a:schemeClr val="accent1"><a:lumMod val="50000"/></a:schemeClr></a:solidFill></a:ln></p:spPr>
            <p:txBody><a:bodyPr anchor="ctr"/><a:lstStyle/><a:p><a:pPr algn="ctr"/><a:r><a:rPr lang="en-US" sz="2400" b="1"><a:solidFill><a:srgbClr val="FFFFFF"/></a:solidFill></a:rPr><a:t>Centred in a shape</a:t></a:r></a:p></p:txBody></p:sp>
            <p:sp><p:nvSpPr><p:cNvPr id="13" name="Arrow"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="6705600" y="3429000"/><a:ext cx="2286000" cy="914400"/></a:xfrm>
            <a:prstGeom prst="rightArrow"><a:avLst/></a:prstGeom><a:solidFill><a:schemeClr val="accent6"/></a:solidFill></p:spPr></p:sp>
            <p:pic><p:nvPicPr><p:cNvPr id="14" name="Pic"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rIdP"/></p:blipFill>
            <p:spPr><a:xfrm><a:off x="9296400" y="3429000"/><a:ext cx="2057400" cy="914400"/></a:xfrm><a:prstGeom prst="ellipse"/></p:spPr></p:pic>
            <p:graphicFrame><p:nvGraphicFramePr><p:cNvPr id="15" name="Table"/><p:cNvGraphicFramePr/><p:nvPr/></p:nvGraphicFramePr>
            <p:xfrm><a:off x="6705600" y="4572000"/><a:ext cx="4648200" cy="1219200"/></p:xfrm><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">
            <a:tbl><a:tblPr><a:tableStyleId>{5C22544A}</a:tableStyleId></a:tblPr><a:tblGrid><a:gridCol w="2324100"/><a:gridCol w="2324100"/></a:tblGrid>
            <a:tr h="609600"><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:rPr b="1"/><a:t>Feature</a:t></a:r></a:p></a:txBody><a:tcPr><a:solidFill><a:schemeClr val="accent1"><a:lumMod val="20000"/><a:lumOff val="80000"/></a:schemeClr></a:solidFill></a:tcPr></a:tc>
            <a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:rPr b="1"/><a:t>Status</a:t></a:r></a:p></a:txBody><a:tcPr><a:solidFill><a:schemeClr val="accent1"><a:lumMod val="20000"/><a:lumOff val="80000"/></a:schemeClr></a:solidFill></a:tcPr></a:tc></a:tr>
            <a:tr h="609600"><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>Tables</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc><a:tc><a:txBody><a:bodyPr/><a:p><a:r><a:t>Imported</a:t></a:r></a:p></a:txBody><a:tcPr/></a:tc></a:tr>
            </a:tbl></a:graphicData></a:graphic></p:graphicFrame>
            """, notes: "Sample notes", images: ["rIdP": TestImages.png(red: 0.2, green: 0.6, blue: 1)])]
        return builder.data()
    }
}
