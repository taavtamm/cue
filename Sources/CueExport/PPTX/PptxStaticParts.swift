/// The fixed parts of a .pptx: content types, package relationships,
/// properties, theme, one slide master with a blank layout, and a notes
/// master. Minimal but complete enough for PowerPoint, Keynote and Google
/// Slides. Everything slide-specific is in `PptxSlideXML`.
enum PptxStaticParts {
    static let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"# + "\n"
    static let ns = #"xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" "#
        + #"xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" "#
        + #"xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main""#
    static let relType = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/"

    static func contentTypes(slides: Int) -> String {
        let pml = "application/vnd.openxmlformats-officedocument.presentationml"
        var overrides = [
            ("/ppt/presentation.xml", "\(pml).presentation.main+xml"),
            ("/ppt/slideMasters/slideMaster1.xml", "\(pml).slideMaster+xml"),
            ("/ppt/slideLayouts/slideLayout1.xml", "\(pml).slideLayout+xml"),
            ("/ppt/notesMasters/notesMaster1.xml", "\(pml).notesMaster+xml"),
            ("/ppt/theme/theme1.xml", "application/vnd.openxmlformats-officedocument.theme+xml"),
            ("/ppt/theme/theme2.xml", "application/vnd.openxmlformats-officedocument.theme+xml"),
            ("/ppt/presProps.xml", "\(pml).presProps+xml"),
            ("/ppt/viewProps.xml", "\(pml).viewProps+xml"),
            ("/ppt/tableStyles.xml", "\(pml).tableStyles+xml"),
            ("/docProps/core.xml", "application/vnd.openxmlformats-package.core-properties+xml"),
            ("/docProps/app.xml", "application/vnd.openxmlformats-officedocument.extended-properties+xml"),
        ]
        for n in 1...max(1, slides) {
            overrides.append(("/ppt/slides/slide\(n).xml", "\(pml).slide+xml"))
            overrides.append(("/ppt/notesSlides/notesSlide\(n).xml", "\(pml).notesSlide+xml"))
        }
        return header + #"<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">"#
            + #"<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>"#
            + #"<Default Extension="xml" ContentType="application/xml"/>"#
            + #"<Default Extension="png" ContentType="image/png"/>"#
            + #"<Default Extension="jpeg" ContentType="image/jpeg"/>"#
            + #"<Default Extension="gif" ContentType="image/gif"/>"#
            + overrides.map { #"<Override PartName="\#($0.0)" ContentType="\#($0.1)"/>"# }.joined()
            + "</Types>"
    }

    static func relationships(_ items: [(id: String, type: String, target: String)]) -> String {
        header + #"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#
            + items.map { #"<Relationship Id="\#($0.id)" Type="\#(relType)\#($0.type)" Target="\#($0.target)"/>"# }.joined()
            + "</Relationships>"
    }

    static let packageRelationships = header
        + #"<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">"#
        + #"<Relationship Id="rId1" Type="\#(relType)officeDocument" Target="ppt/presentation.xml"/>"#
        + #"<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>"#
        + #"<Relationship Id="rId3" Type="\#(relType)extended-properties" Target="docProps/app.xml"/>"#
        + "</Relationships>"

    static func core(title: String) -> String {
        header + #"<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" "#
            + #"xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" "#
            + #"xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">"#
            + "<dc:title>\(XMLText.escape(title))</dc:title><dc:creator>Cue</dc:creator></cp:coreProperties>"
    }

    static func app(slides: Int) -> String {
        header + #"<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">"#
            + "<Application>Cue</Application><Slides>\(slides)</Slides><Notes>\(slides)</Notes></Properties>"
    }

    static func presentation(slides: Int, width: Int, height: Int) -> String {
        let ids = (1...max(1, slides)).map { #"<p:sldId id="\#(255 + $0)" r:id="rId\#($0 + 2)"/>"# }.joined()
        return header + "<p:presentation \(ns) saveSubsetFonts=\"1\">"
            + #"<p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>"#
            + #"<p:notesMasterIdLst><p:notesMasterId r:id="rId2"/></p:notesMasterIdLst>"#
            + "<p:sldIdLst>\(ids)</p:sldIdLst>"
            + #"<p:sldSz cx="\#(width)" cy="\#(height)"/><p:notesSz cx="6858000" cy="9144000"/>"#
            + "</p:presentation>"
    }

    /// rId1 master, rId2 notes master, rId3… slides, then theme and properties.
    static func presentationRelationships(slides: Int) -> String {
        var items: [(String, String, String)] = [
            ("rId1", "slideMaster", "slideMasters/slideMaster1.xml"),
            ("rId2", "notesMaster", "notesMasters/notesMaster1.xml"),
        ]
        for n in 1...max(1, slides) { items.append(("rId\(n + 2)", "slide", "slides/slide\(n).xml")) }
        let next = slides + 3
        items += [
            ("rId\(next)", "theme", "theme/theme1.xml"),
            ("rId\(next + 1)", "presProps", "presProps.xml"),
            ("rId\(next + 2)", "viewProps", "viewProps.xml"),
            ("rId\(next + 3)", "tableStyles", "tableStyles.xml"),
        ]
        return relationships(items)
    }

    static let presProps = header + "<p:presentationPr \(ns)/>"
    static let viewProps = header + "<p:viewPr \(ns)><p:normalViewPr/><p:gridSpacing cx=\"76200\" cy=\"76200\"/></p:viewPr>"
    static let tableStyles = header
        + #"<a:tblStyleLst xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" def="{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}"/>"#

    static let emptyTree = #"<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"#
        + #"<p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>"#
    static let colorMap = #"bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" "#
        + #"accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink""#

    static let slideMaster = header + "<p:sldMaster \(ns)><p:cSld><p:spTree>\(emptyTree)</p:spTree></p:cSld>"
        + "<p:clrMap \(colorMap)/>"
        + #"<p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>"#
    static let slideMasterRelationships = relationships([
        ("rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"), ("rId2", "theme", "../theme/theme1.xml"),
    ])

    static let slideLayout = header + "<p:sldLayout \(ns) type=\"blank\" preserve=\"1\">"
        + "<p:cSld name=\"Blank\"><p:spTree>\(emptyTree)</p:spTree></p:cSld>"
        + "<p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>"
    static let slideLayoutRelationships = relationships([("rId1", "slideMaster", "../slideMasters/slideMaster1.xml")])

    static let notesMaster = header + "<p:notesMaster \(ns)><p:cSld><p:spTree>\(emptyTree)"
        + PptxSlideXML.placeholder(id: 2, name: "Slide Image Placeholder 1", type: "sldImg",
                                   frame: .init(x: 1143000, y: 685800, width: 4572000, height: 3429000), text: nil)
        + PptxSlideXML.placeholder(id: 3, name: "Notes Placeholder 2", type: "body",
                                   frame: .init(x: 685800, y: 4343400, width: 5486400, height: 4114800), text: nil)
        + "</p:spTree></p:cSld><p:clrMap \(colorMap)/></p:notesMaster>"
    static let notesMasterRelationships = relationships([("rId1", "theme", "../theme/theme2.xml")])
}
