import AppKit
import CueCore
import WebKit

/// What exports need from a surface: show a slide and know it has been
/// applied, read it as editable parts, hide those parts, and take pictures
/// or a PDF of the slide's canvas.
extension SlideRenderer {
    /// Shows a slide and returns once the page has applied it and painted.
    public func showNow(_ position: ShowPosition, finished: Bool) async throws {
        self.show(position, finished: finished)
        let message = BridgeCommand.show(position, finished: finished).wireMessage
        _ = try await callInBridge("window.__cue.receive(message); return true", arguments: ["message": message])
        await waitForPaint()
    }

    /// The slide's text boxes and pictures (and marks them for `hideExportParts`).
    public func exportLayout(slide index: Int, slideSelector: String, canvasWidth: Double) async throws -> ExportLayout? {
        let value = try await callInBridge(
            "return JSON.stringify(window.__cue.exporter.collect(selector, index, width))",
            arguments: ["selector": slideSelector, "index": index, "width": canvasWidth]
        )
        guard let text = value as? String, text != "null" else { return nil }
        return try JSONDecoder().decode(ExportLayout.self, from: Data(text.utf8))
    }

    /// Hides (or shows again) the parts `exportLayout` returned, keeping layout.
    public func hideExportParts(_ hidden: Bool) async throws {
        _ = try await callInBridge("window.__cue.exporter.hideMarked(on); return true", arguments: ["on": hidden])
        await waitForPaint()
    }

    /// Leaves picture `index` (in `exportLayout`'s order) in the background picture.
    public func keepInBackground(imageAt index: Int) async throws {
        _ = try await callInBridge("window.__cue.exporter.keepInBackground(i); return true", arguments: ["i": index])
    }

    public func clearExportMarks() async {
        _ = try? await callInBridge("window.__cue.exporter.clear(); return true")
    }

    /// A picture of the canvas `pixelWidth` pixels wide. `canvas` is in CSS pixels.
    public func canvasPicture(_ canvas: ExportLayout.Box, pixelWidth: Double) async throws -> CGImage {
        guard let webView, isReady else { throw SlideRendererError.notReady }
        let configuration = WKSnapshotConfiguration()
        configuration.rect = canvas.rect // Web view coordinates are CSS pixels, top-left.
        configuration.afterScreenUpdates = true
        let scale = webView.window?.backingScaleFactor ?? 2
        configuration.snapshotWidth = NSNumber(value: pixelWidth / scale)
        let image = try await webView.takeSnapshot(configuration: configuration)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw SlideRendererError.notReady
        }
        return cgImage
    }

    /// A one-page PDF of the canvas (text stays text where WebKit keeps it).
    public func canvasPDF(_ canvas: ExportLayout.Box) async throws -> Data {
        guard let webView, isReady else { throw SlideRendererError.notReady }
        let configuration = WKPDFConfiguration()
        configuration.rect = canvas.rect
        return try await webView.pdf(configuration: configuration)
    }
}
