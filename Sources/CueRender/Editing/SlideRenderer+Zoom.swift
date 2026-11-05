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
        // The latest frame on screen. A cached one (afterScreenUpdates false)
        // can come back blank, which showed as a white flash.
        configuration.afterScreenUpdates = true
        return try await webView.takeSnapshot(configuration: configuration)
    }

    /// Returns once the page has painted at its current size and that frame
    /// has reached the screen: two animation frames for layout and paint,
    /// then a snapshot that WebKit only delivers after the next screen update.
    public func waitForPaint() async {
        _ = try? await callInBridge("await new Promise((done) => requestAnimationFrame(() => requestAnimationFrame(done)))")
        guard let webView else { return }
        let barrier = WKSnapshotConfiguration()
        barrier.rect = CGRect(x: 0, y: 0, width: 4, height: 4)
        barrier.snapshotWidth = 4
        barrier.afterScreenUpdates = true
        _ = try? await webView.takeSnapshot(configuration: barrier)
    }
}
