import AppKit
import CueCore
import CueRender
import Foundation
import Testing
@testable import CueImport

/// Opt-in: `CUE_IMPORT_RENDER_DIR=/path swift test --filter RenderSnapshot`
/// converts the real deck and saves PNGs of slides as Cue presents them.
/// Renders stay outside the repo; the deck is private.
@Suite("Render imported slides", .serialized)
@MainActor
struct RenderSnapshotTests {
    nonisolated static let output = ProcessInfo.processInfo.environment["CUE_IMPORT_RENDER_DIR"]
    nonisolated static let source = ProcessInfo.processInfo.environment["CUE_IMPORT_RENDER_SOURCE"].map(URL.init(fileURLWithPath:))
        ?? RealDeckTests.pptx

    @Test(.enabled(if: output != nil && (source.lastPathComponent == "sample.pptx" || FileManager.default.fileExists(atPath: source.path))))
    func rendersConvertedSlides() async throws {
        let folder = URL(fileURLWithPath: Self.output!)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let work = folder.appendingPathComponent("work")
        try? FileManager.default.removeItem(at: work)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let copy = work.appendingPathComponent(Self.source.lastPathComponent)
        if Self.source.lastPathComponent == "sample.pptx" {
            try SampleDeck.data().write(to: copy)
        } else {
            try FileManager.default.copyItem(at: Self.source, to: copy)
        }
        let prepared = try await ImportService().prepare(copy)
        let document = try DeckDocument(contentsOf: prepared.htmlURL)

        let renderer = SlideRenderer(surface: .export)
        let window = NSWindow(contentRect: CGRect(x: -4000, y: 0, width: 1280, height: 720), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = renderer
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        try await renderer.load(DeckSource(document: document))
        let slides = ProcessInfo.processInfo.environment["CUE_IMPORT_RENDER_SLIDES"]?
            .split(separator: ",").compactMap { Int($0) } ?? Array(1...min(4, document.structure.slides.count))
        for number in slides where number <= document.structure.slides.count {
            renderer.show(ShowPosition(slide: number - 1), finished: true)
            try await Task.sleep(for: .milliseconds(900))
            let image = try await renderer.snapshot()
            guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            try png.write(to: folder.appendingPathComponent("cue-slide\(number).png"))
        }
        print("Report:", prepared.report?.summaryLines ?? [])
    }
}
