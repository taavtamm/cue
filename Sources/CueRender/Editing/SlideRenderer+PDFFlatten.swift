import AppKit
import CueCore
import WebKit

/// WebKit writes CSS gradients into a PDF without their transparency: a
/// gradient fading into a photo comes out solid, a gradient mask black.
/// Before a slide becomes a PDF page, each such box gets a picture of itself
/// as its background (see `94-pdf-flatten.js`); text elsewhere stays text.
extension SlideRenderer {
    /// Swaps the slide's see-through gradients and gradient masks for
    /// pictures. Returns how many boxes changed. Undo with `restoreFlattened`.
    @discardableResult
    public func flattenSeeThroughGradients(slide index: Int, slideSelector: String) async throws -> Int {
        let value = try await callInBridge(
            "return JSON.stringify(window.__cue.pdfFlatten.find(selector, index))",
            arguments: ["selector": slideSelector, "index": index]
        )
        guard let text = value as? String else { return 0 }
        let boxes = try JSONDecoder().decode([ExportLayout.Box].self, from: Data(text.utf8))
        for (item, box) in boxes.enumerated() {
            _ = try await callInBridge("window.__cue.pdfFlatten.isolate(i); return true", arguments: ["i": item])
            let picture = try await canvasPicture(box, pixelWidth: min(box.width, 4096), seeThrough: true)
            let bitmap = NSBitmapImageRep(cgImage: picture)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { continue }
            let url = "data:image/png;base64," + png.base64EncodedString()
            _ = try await callInBridge("window.__cue.pdfFlatten.replace(i, url); return true",
                                       arguments: ["i": item, "url": url])
        }
        if !boxes.isEmpty { await waitForPaint() }
        return boxes.count
    }

    /// Puts back what `flattenSeeThroughGradients` changed.
    public func restoreFlattened() async {
        _ = try? await callInBridge("window.__cue.pdfFlatten.restore(); return true")
    }
}
