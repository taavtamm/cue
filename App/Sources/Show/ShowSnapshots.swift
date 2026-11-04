#if DEBUG
import AppKit
import CueCore
import CueRender

/// Debug-only: saves PNGs of the live stage, so a show can be checked
/// without screen-recording permission.
///
///     Cue -open deck.html -present YES -snapshotDir /tmp/shots -snapshotSlides 1,2,4
@MainActor
enum ShowSnapshots {
    static var request: (folder: URL, slides: [Int])? {
        guard let path = UserDefaults.standard.string(forKey: "snapshotDir") else { return nil }
        let slides = (UserDefaults.standard.string(forKey: "snapshotSlides") ?? "1")
            .split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map { $0 - 1 }
        return (URL(filePath: path), slides)
    }

    /// Shows each requested slide on the stage, waits for embeds to animate, and saves it.
    static func capture(stage: SlideRenderer, controller: ShowController, render: () -> Void) async {
        guard let request else { return }
        try? FileManager.default.createDirectory(at: request.folder, withIntermediateDirectories: true)
        try? await Task.sleep(for: .seconds(2))
        for slide in request.slides {
            controller.jump(toSlide: slide)
            render()
            for frame in 0..<2 { // Two frames apart, to show whether live content moves.
                try? await Task.sleep(for: .milliseconds(frame == 0 ? 2_500 : 700))
                guard let image = try? await stage.snapshot(), let png = pngData(image) else { continue }
                let file = request.folder.appending(path: "slide\(slide + 1)-\(frame == 0 ? "a" : "b").png")
                try? png.write(to: file)
            }
        }
    }

    private static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
#endif
