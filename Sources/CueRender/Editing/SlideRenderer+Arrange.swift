import CoreGraphics
import CueCore
import Foundation

/// Moving, resizing and snapping on a surface (see `91-arrange.js`).
extension SlideRenderer {
    public func canvasGeometry(slide index: Int, slideSelector: String, canvasWidth: Double) async throws
        -> CanvasGeometry? {
        let value = try await callInBridge(
            "return window.__cue.arrange.canvas(selector, index, width)",
            arguments: ["selector": slideSelector, "index": index, "width": canvasWidth]
        )
        guard let info = value as? [String: Any], let rect = info["rect"] as? [String: Any] else { return nil }
        return CanvasGeometry(frame: viewRect(fromCSS: Self.wireRect(rect)), scale: info["scale"] as? Double ?? 1)
    }

    /// Other boxes on the slide, in canvas pixels, for snapping.
    public func snapTargets(slide index: Int, slideSelector: String, canvasWidth: Double, excluding cueID: String)
        async throws -> [CGRect] {
        let value = try await callInBridge(
            "return window.__cue.arrange.boxes(selector, index, width, exclude)",
            arguments: ["selector": slideSelector, "index": index, "width": canvasWidth, "exclude": cueID]
        )
        return (value as? [[String: Any]] ?? []).map(Self.wireRect)
    }

    /// Shows styles on the live element while dragging; nothing is written.
    public func previewStyles(cueID: String, _ changes: [StyleChange]) {
        var styles: [String: Any] = [:]
        for change in changes { styles[change.property] = change.value ?? NSNull() }
        Task { _ = try? await callInBridge("window.__cue.arrange.preview(id, styles)",
                                           arguments: ["id": cueID, "styles": styles]) }
    }

    /// Ends a preview: `restore` puts the original style back (cancelled drag).
    public func endPreview(cueID: String, restore: Bool) async {
        let call = restore ? "window.__cue.arrange.cancel(id)" : "window.__cue.arrange.forget(id)"
        _ = try? await callInBridge(call, arguments: ["id": cueID])
    }

    static func wireRect(_ values: [String: Any]) -> CGRect {
        CGRect(
            x: values["x"] as? Double ?? 0, y: values["y"] as? Double ?? 0,
            width: values["width"] as? Double ?? 0, height: values["height"] as? Double ?? 0
        )
    }
}
