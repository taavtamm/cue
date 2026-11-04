import AppKit
import Foundation

/// Pausing a surface with live web embeds. The embeds run in sandboxed
/// frames that can't be paused, so each is replaced by a still of what it
/// showed when the user paused (see `62-freeze.js`). This also stops them
/// using the CPU while paused.
extension SlideRenderer {
    /// How long a newly shown slide's embeds get to draw before being frozen.
    static let freezeDelay: Duration = .milliseconds(700)

    func freezeEmbeds() async {
        guard isReady,
              let frames = try? await callInBridge("return window.__cue.freeze.frames()") as? [[String: Any]],
              !frames.isEmpty,
              let picture = try? await snapshot(),
              let image = picture.cgImage(forProposedRect: nil, context: nil, hints: nil),
              isPausedForEditing // Resumed while the picture was being taken.
        else { return }
        let scale = CGFloat(image.width) / max(1, bounds.width)
        let stills: [[String: Any]] = frames.compactMap { frame in
            guard let index = frame["index"] as? Int, let rect = frame["rect"] as? [String: Double],
                  let src = Self.still(of: image, in: rect, scale: scale) else { return nil }
            return ["index": index, "src": src]
        }
        _ = try? await callInBridge("window.__cue.freeze.apply(stills)", arguments: ["stills": stills])
    }

    func thawEmbeds() async {
        _ = try? await callInBridge("window.__cue.freeze.thaw()")
    }

    /// A PNG data URL of one embed's box, cut from the page picture.
    /// `rect` is in page points, top-left origin, like the picture's pixels.
    private static func still(of image: CGImage, in rect: [String: Double], scale: CGFloat) -> String? {
        let box = CGRect(
            x: (rect["x"] ?? 0) * scale, y: (rect["y"] ?? 0) * scale,
            width: (rect["width"] ?? 0) * scale, height: (rect["height"] ?? 0) * scale
        ).integral
        guard let crop = image.cropping(to: box) else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: crop)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return "data:image/png;base64," + png.base64EncodedString()
    }
}
