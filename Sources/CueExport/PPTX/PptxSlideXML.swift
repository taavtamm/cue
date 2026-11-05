import CueRender
import Foundation

/// One slide's XML and relationships, and its notes page.
enum PptxSlideXML {
    /// `rId1` is the layout, `rId2` the background picture, then pictures, then the notes page.
    static func slide(_ slide: ExportedSlide, scale: PptxScale) -> String {
        var id = 2
        var shapes = picture(rid: "rId2", id: id, name: "Slide picture (flattened)",
                             box: CGRect(x: 0, y: 0, width: slide.layout.width, height: slide.layout.height),
                             crop: nil, opacity: 1, scale: scale)
        for (index, item) in slide.pictures.enumerated() {
            id += 1
            shapes += picture(rid: "rId\(index + 3)", id: id, name: "Picture \(index + 1)", box: item.box,
                              crop: item.crop, opacity: item.opacity, scale: scale)
        }
        for text in slide.layout.texts {
            id += 1
            shapes += PptxTextXML.shape(text, id: id, scale: scale)
        }
        return PptxStaticParts.header + "<p:sld \(PptxStaticParts.ns)><p:cSld><p:spTree>\(PptxStaticParts.emptyTree)"
            + shapes + "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>"
    }

    static func slideRelationships(_ slide: ExportedSlide, number: Int) -> String {
        var items: [(String, String, String)] = [
            ("rId1", "slideLayout", "../slideLayouts/slideLayout1.xml"),
            ("rId2", "image", "../media/slide\(number)-background.jpeg"),
        ]
        for (index, item) in slide.pictures.enumerated() {
            items.append(("rId\(index + 3)", "image", "../media/slide\(number)-picture\(index + 1).\(item.fileExtension)"))
        }
        items.append(("rId\(slide.pictures.count + 3)", "notesSlide", "../notesSlides/notesSlide\(number).xml"))
        return PptxStaticParts.relationships(items)
    }

    static func notes(_ text: String) -> String {
        PptxStaticParts.header + "<p:notes \(PptxStaticParts.ns)><p:cSld><p:spTree>\(PptxStaticParts.emptyTree)"
            + placeholder(id: 2, name: "Slide Image Placeholder 1", type: "sldImg", frame: nil, text: nil)
            + placeholder(id: 3, name: "Notes Placeholder 2", type: "body", frame: nil, text: text)
            + "</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:notes>"
    }

    static func notesRelationships(number: Int) -> String {
        PptxStaticParts.relationships([
            ("rId1", "notesMaster", "../notesMasters/notesMaster1.xml"), ("rId2", "slide", "../slides/slide\(number).xml"),
        ])
    }

    static func frame(x: Double, y: Double, width: Double, height: Double, scale: PptxScale) -> String {
        "<a:xfrm><a:off x=\"\(scale.emu(x))\" y=\"\(scale.emu(y))\"/>"
            + "<a:ext cx=\"\(max(1, scale.emu(width)))\" cy=\"\(max(1, scale.emu(height)))\"/></a:xfrm>"
    }

    static func picture(rid: String, id: Int, name: String, box: CGRect,
                        crop: PictureCrop?, opacity: Double,
                        scale: PptxScale) -> String {
        let cut = crop.map { crop in
            let v = { (f: Double) in Int((f * 100_000).rounded()) }
            return "<a:srcRect l=\"\(v(crop.left))\" t=\"\(v(crop.top))\" r=\"\(v(crop.right))\" b=\"\(v(crop.bottom))\"/>"
        } ?? ""
        let fade = opacity < 0.999 ? "<a:alphaModFix amt=\"\(Int((opacity * 100_000).rounded()))\"/>" : ""
        return "<p:pic><p:nvPicPr><p:cNvPr id=\"\(id)\" name=\"\(XMLText.escape(name))\"/>"
            + "<p:cNvPicPr><a:picLocks noChangeAspect=\"1\"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>"
            + "<p:blipFill><a:blip r:embed=\"\(rid)\">\(fade)</a:blip>\(cut)<a:stretch><a:fillRect/></a:stretch></p:blipFill>"
            + "<p:spPr>\(frame(x: box.minX, y: box.minY, width: box.width, height: box.height, scale: scale))"
            + "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:pic>"
    }

    /// A placeholder shape: on the notes master with a frame, on a notes page with text.
    /// A frame in EMU, for the notes master's placeholders.
    struct Frame { let x, y, width, height: Int }

    static func placeholder(id: Int, name: String, type: String, frame: Frame?, text: String?) -> String {
        let index = type == "body" ? " idx=\"1\"" : ""
        let shape = frame.map { f in
            "<p:spPr><a:xfrm><a:off x=\"\(f.x)\" y=\"\(f.y)\"/><a:ext cx=\"\(f.width)\" cy=\"\(f.height)\"/></a:xfrm>"
                + "<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr>"
        } ?? "<p:spPr/>"
        let body = type == "sldImg" ? "" : "<p:txBody><a:bodyPr/><a:lstStyle/>"
            + (text ?? "").components(separatedBy: "\n").map { line in
                line.isEmpty ? "<a:p><a:endParaRPr lang=\"en-US\" dirty=\"0\"/></a:p>"
                    : "<a:p><a:r><a:rPr lang=\"en-US\" dirty=\"0\"/><a:t>\(XMLText.escape(line))</a:t></a:r></a:p>"
            }.joined() + "</p:txBody>"
        let locks = type == "sldImg" ? "<a:spLocks noGrp=\"1\" noRot=\"1\" noChangeAspect=\"1\"/>" : "<a:spLocks noGrp=\"1\"/>"
        return "<p:sp><p:nvSpPr><p:cNvPr id=\"\(id)\" name=\"\(name)\"/><p:cNvSpPr>\(locks)</p:cNvSpPr>"
            + "<p:nvPr><p:ph type=\"\(type)\"\(index)/></p:nvPr></p:nvSpPr>\(shape)\(body)</p:sp>"
    }
}
