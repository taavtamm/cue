import CueCore
import CueRender
import Foundation

extension DeckExport {
    /// One slide as PowerPoint parts: its shapes, text and pictures, and a
    /// picture of whatever else it shows.
    static func slide(_ index: Int, renderer: ExportRenderer, folder: DeckFolder) async throws -> ExportedSlide {
        try await renderer.show(index)
        var layout = try await renderer.layout(index)
        var pictures: [ExportedPicture] = []
        for (imageIndex, image) in layout.images.enumerated() {
            guard let bytes = ImageData.bytes(for: image.source, folder: folder) else {
                try await renderer.renderer.keepInBackground(imageAt: imageIndex)
                layout.unsupported += 1 // An SVG or unreadable image: it stays in the picture.
                continue
            }
            let placement = ImageData.placement(image)
            pictures.append(ExportedPicture(box: placement.box, data: bytes.data, fileExtension: bytes.fileExtension,
                                            crop: placement.crop, opacity: image.opacity, order: image.order))
        }
        try await renderer.renderer.hideExportParts(true)
        let background = try await flattened(layout, renderer: renderer)
        try await renderer.renderer.hideExportParts(false)
        await renderer.renderer.clearExportMarks()
        let notes = renderer.document.structure.slides[index].notes
        return ExportedSlide(layout: layout, background: background, pictures: pictures, notes: notes)
    }

    /// The picture of what's left once the editable parts are hidden. Over a
    /// slide background PowerPoint can draw, it's see-through and cut to what
    /// it shows (nil when that's nothing); otherwise it's the whole slide.
    static func flattened(_ layout: ExportLayout, renderer: ExportRenderer) async throws -> ExportedPicture? {
        let whole = CGRect(x: 0, y: 0, width: layout.width, height: layout.height)
        guard layout.background != nil else {
            let picture = try await renderer.renderer.canvasPicture(layout.canvas, pixelWidth: layout.width)
            guard let jpeg = ImageData.jpeg(picture) else { throw ExportError.couldNotEncode }
            return ExportedPicture(box: whole, data: jpeg, fileExtension: "jpeg")
        }
        let picture = try await renderer.renderer.canvasPicture(layout.canvas, pixelWidth: layout.width, seeThrough: true)
        guard let visible = PictureTrim.trimmed(picture, canvasWidth: layout.width) else { return nil }
        guard let png = ImageData.png(visible.image) else { throw ExportError.couldNotEncode }
        return ExportedPicture(box: visible.box, data: png, fileExtension: "png")
    }
}
