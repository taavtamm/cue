import AppKit
import CueCore
import CueRender
import Foundation
import PDFKit

/// File › Export: PowerPoint (editable, static), PDF and images. Each walks
/// the deck on one `ExportRenderer`, reports progress and stops when the
/// task is cancelled. The deck itself is never changed.
@MainActor
public enum DeckExport {
    public enum Format: String, CaseIterable, Sendable { case powerPoint, pdf, images }

    public struct Result: Sendable {
        public let url: URL
        /// Font families the PowerPoint uses that this Mac doesn't have
        /// installed: PowerPoint may substitute them.
        public let missingFonts: [String]
        public let slides: Int
    }

    public typealias Progress = @MainActor (_ done: Int, _ total: Int) -> Void

    /// An editable .pptx at `url`.
    public static func powerPoint(_ document: DeckDocument, to url: URL, progress: Progress = { _, _ in }) async throws -> Result {
        let renderer = ExportRenderer(document: document)
        defer { renderer.close() }
        try await renderer.start()
        let folder = DeckFolder(root: document.fileURL.deletingLastPathComponent())
        var slides: [ExportedSlide] = []
        for index in 0..<renderer.slideCount {
            progress(index, renderer.slideCount)
            slides.append(try await slide(index, renderer: renderer, folder: folder))
        }
        progress(renderer.slideCount, renderer.slideCount)
        let title = document.fileURL.deletingPathExtension().lastPathComponent
        try PptxWriter.data(slides: slides, title: title).write(to: url, options: .atomic)
        let families = Set(slides.flatMap { $0.layout.texts.flatMap { $0.paragraphs.flatMap { $0.map(\.family) } } })
        return Result(url: url, missingFonts: FontCheck.missing(families), slides: slides.count)
    }

    static func slide(_ index: Int, renderer: ExportRenderer, folder: DeckFolder) async throws -> ExportedSlide {
        try await renderer.show(index)
        let layout = try await renderer.layout(index)
        var pictures: [ExportedPicture] = []
        for (imageIndex, image) in layout.images.enumerated() {
            guard let bytes = ImageData.bytes(for: image.source, folder: folder) else {
                try await renderer.renderer.keepInBackground(imageAt: imageIndex)
                continue
            }
            let placement = ImageData.placement(image)
            pictures.append(ExportedPicture(box: placement.box, data: bytes.data, fileExtension: bytes.fileExtension,
                                            crop: placement.crop, opacity: image.opacity))
        }
        try await renderer.renderer.hideExportParts(true)
        let picture = try await renderer.renderer.canvasPicture(layout.canvas, pixelWidth: layout.width)
        try await renderer.renderer.hideExportParts(false)
        await renderer.renderer.clearExportMarks()
        guard let background = ImageData.jpeg(picture) else { throw ExportError.couldNotEncode }
        let notes = renderer.document.structure.slides[index].notes
        return ExportedSlide(layout: layout, background: background, pictures: pictures, notes: notes)
    }

    /// A PDF with one page per slide, at the slide's aspect.
    public static func pdf(_ document: DeckDocument, to url: URL, progress: Progress = { _, _ in }) async throws -> Result {
        let renderer = ExportRenderer(document: document)
        defer { renderer.close() }
        try await renderer.start()
        let output = PDFDocument()
        for index in 0..<renderer.slideCount {
            progress(index, renderer.slideCount)
            try await renderer.show(index)
            let layout = try await renderer.layout(index)
            await renderer.renderer.clearExportMarks()
            let data = try await renderer.renderer.canvasPDF(layout.canvas)
            if let page = PDFDocument(data: data)?.page(at: 0) { output.insert(page, at: output.pageCount) }
        }
        progress(renderer.slideCount, renderer.slideCount)
        guard output.write(to: url) else { throw CocoaError(.fileWriteUnknown) }
        return Result(url: url, missingFonts: [], slides: output.pageCount)
    }

    /// One PNG per slide in `folder`, "<Deck> – 01.png"…, at `scale` × the canvas size.
    public static func images(_ document: DeckDocument, to folder: URL, scale: Double = 2,
                              progress: Progress = { _, _ in }) async throws -> Result {
        let renderer = ExportRenderer(document: document)
        defer { renderer.close() }
        try await renderer.start()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = document.fileURL.deletingPathExtension().lastPathComponent
        let digits = max(2, String(renderer.slideCount).count)
        for index in 0..<renderer.slideCount {
            progress(index, renderer.slideCount)
            try await renderer.show(index)
            let layout = try await renderer.layout(index)
            await renderer.renderer.clearExportMarks()
            let picture = try await renderer.renderer.canvasPicture(layout.canvas, pixelWidth: layout.width * scale)
            guard let png = ImageData.png(picture) else { throw ExportError.couldNotEncode }
            let number = String(format: "%0\(digits)d", index + 1)
            try png.write(to: folder.appending(path: "\(name) – \(number).png"), options: .atomic)
        }
        progress(renderer.slideCount, renderer.slideCount)
        return Result(url: folder, missingFonts: [], slides: renderer.slideCount)
    }
}
