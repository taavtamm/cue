import AppKit
import WebKit

/// Helpers for changing the editor's zoom without a flicker: a picture of
/// what is on screen to stand in while the page re-renders at its new size,
/// and a way to know when it has.
extension SlideRenderer {
    /// A picture of part of the surface. `rect` is in this view's
    /// coordinates (origin bottom-left), like the rest of AppKit.
    public func snapshot(of rect: CGRect) async throws -> NSImage {
        guard let webView, isReady else { throw SlideRendererError.notReady }
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(x: rect.minX, y: bounds.height - rect.maxY, width: rect.width, height: rect.height)
        configuration.afterScreenUpdates = false // What the user sees now, not a fresh layout.
        return try await webView.takeSnapshot(configuration: configuration)
    }

    /// Returns once the page has painted at its current size: two animation
    /// frames, the first to lay out at the new size, the second to show it.
    public func waitForPaint() async {
        _ = try? await callInBridge("await new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)))")
    }
}
