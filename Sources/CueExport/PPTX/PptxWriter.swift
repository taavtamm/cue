import Foundation

/// Writes exported slides as an editable .pptx: per slide, the background
/// fill, a flattened picture of what PowerPoint can't draw, then shapes,
/// pictures and real text boxes (with the deck's fonts, sizes and colours)
/// in the slide's paint order, and the speaker notes. Animations and live
/// content are frozen.
public enum PptxWriter {
    public static func data(slides: [ExportedSlide], title: String) -> Data {
        let canvasWidth = slides.first?.layout.width ?? 1920
        let canvasHeight = slides.first?.layout.height ?? 1080
        let scale = PptxScale(canvasWidth: canvasWidth)
        let count = slides.count
        var zip = ZipWriter()
        zip.add("[Content_Types].xml", PptxStaticParts.contentTypes(slides: count))
        zip.add("_rels/.rels", PptxStaticParts.packageRelationships)
        zip.add("docProps/core.xml", PptxStaticParts.core(title: title))
        zip.add("docProps/app.xml", PptxStaticParts.app(slides: count))
        zip.add("ppt/presentation.xml", PptxStaticParts.presentation(
            slides: count, width: scale.emu(canvasWidth), height: scale.emu(canvasHeight)
        ))
        zip.add("ppt/_rels/presentation.xml.rels", PptxStaticParts.presentationRelationships(slides: count))
        zip.add("ppt/presProps.xml", PptxStaticParts.presProps)
        zip.add("ppt/viewProps.xml", PptxStaticParts.viewProps)
        zip.add("ppt/tableStyles.xml", PptxStaticParts.tableStyles)
        zip.add("ppt/theme/theme1.xml", PptxTheme.xml(name: "Cue"))
        zip.add("ppt/theme/theme2.xml", PptxTheme.xml(name: "Cue Notes"))
        zip.add("ppt/slideMasters/slideMaster1.xml", PptxStaticParts.slideMaster)
        zip.add("ppt/slideMasters/_rels/slideMaster1.xml.rels", PptxStaticParts.slideMasterRelationships)
        zip.add("ppt/slideLayouts/slideLayout1.xml", PptxStaticParts.slideLayout)
        zip.add("ppt/slideLayouts/_rels/slideLayout1.xml.rels", PptxStaticParts.slideLayoutRelationships)
        zip.add("ppt/notesMasters/notesMaster1.xml", PptxStaticParts.notesMaster)
        zip.add("ppt/notesMasters/_rels/notesMaster1.xml.rels", PptxStaticParts.notesMasterRelationships)
        for (index, slide) in slides.enumerated() {
            let number = index + 1
            zip.add("ppt/slides/slide\(number).xml", PptxSlideXML.slide(slide, scale: scale))
            zip.add("ppt/slides/_rels/slide\(number).xml.rels", PptxSlideXML.slideRelationships(slide, number: number))
            zip.add("ppt/notesSlides/notesSlide\(number).xml", PptxSlideXML.notes(slide.notes))
            zip.add("ppt/notesSlides/_rels/notesSlide\(number).xml.rels", PptxSlideXML.notesRelationships(number: number))
            if let background = slide.background {
                zip.add("ppt/media/slide\(number)-background.\(background.fileExtension)", background.data, compress: false)
            }
            for (pictureIndex, picture) in slide.pictures.enumerated() {
                zip.add("ppt/media/slide\(number)-picture\(pictureIndex + 1).\(picture.fileExtension)", picture.data,
                        compress: false)
            }
        }
        return zip.data()
    }
}
