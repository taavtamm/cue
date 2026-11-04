import AppKit
import SwiftUI
import Testing
@testable import CueUI

/// Renders the gallery and a caret close-up to PNGs for visual review.
/// Runs only when CUE_RENDER_DIR is set:
///
///     CUE_RENDER_DIR=/tmp/cue swift test --filter GalleryRender
@Suite("Gallery render", .enabled(if: ProcessInfo.processInfo.environment["CUE_RENDER_DIR"] != nil))
@MainActor
struct GalleryRenderTests {
    let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CUE_RENDER_DIR"] ?? "/tmp")

    @Test func renderGallery() throws {
        try render(ComponentGallery(), size: CGSize(width: 1240, height: 860), name: "gallery.png")
    }

    /// The caret is Core Animation layers, which `cacheDisplay` skips, so
    /// draw the field first, then composite the caret layer over it.
    @Test func renderCaretCloseUp() throws {
        let scale: CGFloat = 4
        let size = CGSize(width: 360, height: 100)
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        let root = NSView(frame: CGRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(srgbRed: 7 / 255, green: 7 / 255, blue: 10 / 255, alpha: 1).cgColor
        window.contentView = root
        addSampleFields(to: root)
        let rep = try #require(root.bitmapImageRepForCachingDisplay(in: root.bounds))
        root.cacheDisplay(in: root.bounds, to: rep)
        try writeComposite(root: root, capture: rep, scale: scale, name: "caret.png")
    }

    private func addSampleFields(to root: NSView) {
        for (index, style) in [GlowTextStyle.ask, .launcher].enumerated() {
            let editor = GlowTextEditorView(style: style)
            editor.frame = CGRect(x: 24, y: index == 0 ? 8 : 34, width: 320, height: index == 0 ? 24 : 60)
            editor.textView.string = index == 0 ? "Tighten headline" : "Cue"
            editor.caretOverlay.reduceMotion = { true }
            root.addSubview(editor)
            editor.layoutSubtreeIfNeeded()
            editor.textView.setSelectedRange(NSRange(location: index == 0 ? 8 : 3, length: 0))
            editor.caretOverlay.setFocused(true)
            editor.layout()
        }
    }

    private func writeComposite(root: NSView, capture rep: NSBitmapImageRep, scale: CGFloat, name: String) throws {
        let size = root.bounds.size
        let upscaled = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        upscaled.size = size
        let context = try #require(NSGraphicsContext(bitmapImageRep: upscaled))
        NSGraphicsContext.current = context
        rep.draw(in: root.bounds)
        let cg = context.cgContext
        for editor in root.subviews.compactMap({ $0 as? GlowTextEditorView }) {
            let origin = root.convert(editor.caretOverlay.bounds, from: editor.caretOverlay)
            cg.saveGState()
            // Root is y-up; the overlay is flipped, so flip into its space.
            cg.translateBy(x: origin.minX, y: origin.maxY)
            cg.scaleBy(x: 1, y: -1)
            // render(in:) ignores screen blending and misplaces bitmap contents in
            // flipped trees, so draw the bloom bitmap at its frame by hand.
            let caret = editor.caretOverlay.caret
            let bloomLayer = try #require(caret.sublayers?.first)
            let bloom = bloomLayer.contents as! CGImage // swiftlint:disable:this force_cast
            let frame = caret.convert(bloomLayer.frame, to: editor.caretOverlay.layer)
            cg.saveGState()
            cg.translateBy(x: frame.minX, y: frame.maxY)
            cg.scaleBy(x: 1, y: -1)
            cg.setBlendMode(.screen)
            cg.draw(bloom, in: CGRect(origin: .zero, size: frame.size))
            cg.restoreGState()
            bloomLayer.isHidden = true
            editor.caretOverlay.layer?.render(in: cg)
            bloomLayer.isHidden = false
            cg.restoreGState()
        }
        NSGraphicsContext.current = nil
        let data = try #require(upscaled.representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent(name))
    }

    private func render(_ view: some View, size: CGSize, name: String, scale: CGFloat = 2) throws {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        host.frame = CGRect(origin: .zero, size: size)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))

        let pixels = NSSize(width: size.width * scale, height: size.height * scale)
        let rep = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        let data = try #require(rep.representation(using: .png, properties: [:]))
        try data.write(to: directory.appendingPathComponent(name))

        // ImageRenderer draws pure SwiftUI faithfully, but shows AppKit-backed
        // views (the glow text fields) as placeholders. Kept for comparison.
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try png.write(to: directory.appendingPathComponent("swiftui-" + name))
        }
    }
}
