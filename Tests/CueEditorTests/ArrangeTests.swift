import AppKit
import CoreGraphics
@testable import CueCore
import Foundation
import Testing
@testable import CueEditor
@testable import CueRender

@Suite("Canvas zoom and geometry")
@MainActor
struct CanvasZoomTests {
    @Test func zoomStepsAndRange() {
        let zoom = CanvasZoom()
        #expect(zoom.readout == "Fit")
        #expect(zoom.zoomedIn() == 1.5)
        zoom.set(20)
        #expect(zoom.scale == 8)
        #expect(zoom.zoomedOut() == 6)
        zoom.set(0.2)
        #expect(zoom.isFit)
        #expect(zoom.smartMagnified() == 2)
    }

    @Test func livePinchKeepsThePointUnderTheFingersWhenItSettles() {
        // At fit, the fingers are 300×200 pt into the view. Pinching to 2×
        // magnifies about that point: the clip's origin moves to 150×100 in
        // content units. After re-rendering at 2× the origin must be 300×200,
        // the same answer as zooming in one step.
        let origin = CanvasZoom.originAfterPinch(
            pointer: CGPoint(x: 300, y: 200), pointerInClip: CGPoint(x: 300, y: 200),
            clipOrigin: CGPoint(x: 150, y: 100), magnification: 2, old: 1, new: 2
        )
        #expect(origin == CGPoint(x: 300, y: 200))
        #expect(origin == CanvasZoom.anchoredOrigin(anchor: CGPoint(x: 300, y: 200), visibleOrigin: .zero, old: 1, new: 2))
    }

    @Test func pinchKeepsThePointUnderTheFingers() {
        // At 1×, the pointer is 300 pt into a view scrolled to 0. Zooming to 2×
        // puts that content point at 600; scroll 300 so it stays under the pointer.
        let origin = CanvasZoom.anchoredOrigin(anchor: CGPoint(x: 300, y: 200), visibleOrigin: .zero, old: 1, new: 2)
        #expect(origin == CGPoint(x: 300, y: 200))
        let deeper = CanvasZoom.anchoredOrigin(anchor: CGPoint(x: 900, y: 500), visibleOrigin: CGPoint(x: 600, y: 300),
                                               old: 2, new: 4)
        #expect(deeper == CGPoint(x: 1500, y: 800))
    }

    @Test func dragsConvertThroughZoom() {
        // At 400% of a 1920-wide canvas shown 960 pt wide at fit, 1 canvas px = 2 pt.
        let zoomed = CanvasGeometry(frame: CGRect(x: 0, y: 0, width: 3840, height: 2160), scale: 2)
        #expect(zoomed.canvasDelta(fromView: CGSize(width: 10, height: 0)).width == 5)
        let deep = CanvasGeometry(frame: CGRect(x: 0, y: 0, width: 7680, height: 4320), scale: 4)
        #expect(deep.canvasDelta(fromView: CGSize(width: 10, height: -10)) == CGSize(width: 2.5, height: 2.5))
    }

    @Test func viewAndCanvasRectsRoundTrip() {
        let geometry = CanvasGeometry(frame: CGRect(x: 40, y: 30, width: 960, height: 540), scale: 0.5)
        let canvas = CGRect(x: 100, y: 200, width: 400, height: 100)
        let view = geometry.viewRect(fromCanvas: canvas)
        #expect(view == CGRect(x: 90, y: 420, width: 200, height: 50)) // AppKit: origin bottom-left.
        #expect(geometry.canvasRect(fromView: view) == canvas)
    }
}

@Suite("Image embedding")
struct ImageEmbedderTests {
    static func png(width: Int, height: Int) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        return rep.representation(using: .png, properties: [:])!
    }

    @Test func smallImagesKeepTheirBytes() throws {
        let data = Self.png(width: 200, height: 100)
        let embedded = try ImageEmbedder(canvas: CGSize(width: 1920, height: 1080)).embed(data)
        #expect(embedded.dataURI == "data:image/png;base64," + data.base64EncodedString())
        #expect(embedded.note == nil)
    }

    @Test func hugeImagesAreScaledToTwiceTheCanvas() throws {
        let embedded = try ImageEmbedder(canvas: CGSize(width: 1920, height: 1080)).embed(Self.png(width: 8000, height: 3000))
        #expect(embedded.pixelSize.width <= 3840 && embedded.pixelSize.height <= 2160)
        #expect(embedded.pixelSize.width == 3840)
        #expect(embedded.note?.contains("8000") == true)
        #expect(embedded.dataURI.hasPrefix("data:image/png;base64,"))
    }
}

/// Moving, resizing and inserting on the real demo deck.
@Suite("Hand editing on the canvas", .serialized)
@MainActor
struct HandEditingSessionTests {
    private func open(slide: Int = 2) async throws -> SessionHarness {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        try await harness.load(slide: slide)
        return harness
    }

    @Test func draggingAHeadingIsOneTranslatePatchAndUndoesExactly() async throws {
        let harness = try await open()
        defer { harness.close() }
        let session = harness.session
        let original = session.document.source
        let heading = try #require(session.document.heading(onSlide: 2))
        _ = await session.click(at: try await harness.centre(of: heading.cueID))
        var drag = try #require(await session.beginDrag(.move))
        drag.update(delta: CGSize(width: 100, height: 0), shift: false, noSnapping: true)
        session.preview(drag)
        await session.commit(drag, duplicate: false)
        #expect(session.document.history.undoCount == 1)
        let patches = try #require(session.document.history.lastForward)
        #expect(patches.patches.count == 1)
        #expect(session.document.source.contains("translate: 100px 0px"))
        // The page shows the new place too.
        let moved = try #require(await session.canvas.inspect(
            cueID: heading.cueID, slideSelector: session.structure.slideSelector, canvasWidth: 1920))
        #expect(abs(moved.canvasFrame.minX - drag.start.minX - 100) < 1)
        await session.undo()
        #expect(session.document.source == original)
    }

    @Test func insertingATextBoxThenResizingIt() async throws {
        let harness = try await open()
        defer { harness.close() }
        let session = harness.session
        #expect(await session.insert(.textBox(text: "Hello", fontSize: 48, fontFamily: nil)))
        let selected = try #require(session.selection)
        #expect(selected.element.attributes["data-cue-element"] == "text")
        try await harness.waitUntil("inspected") { session.selection?.inspection != nil }
        var drag = try #require(await session.beginDrag(.resize([.right, .bottom])))
        drag.update(delta: CGSize(width: 120, height: 40), shift: false, noSnapping: true)
        await session.commit(drag, duplicate: false)
        let style = try #require(session.document.sourceMap.elements.first { $0.attributes["data-cue-element"] == "text" })
            .attributes["style"]
        let width = Int((drag.start.width + 120).rounded())
        #expect(style?.contains("width: \(width)px") == true)
        #expect(session.structure.slides.count == 12)
    }

    @Test func insertingAnImageThenUndoing() async throws {
        let harness = try await open()
        defer { harness.close() }
        let session = harness.session
        let original = session.document.source
        let file = FileManager.default.temporaryDirectory.appending(path: "cue-\(UUID().uuidString).png")
        try ImageEmbedderTests.png(width: 400, height: 200).write(to: file)
        #expect(await session.insertImage(contentsOf: file))
        #expect(session.document.source.contains("data:image/png;base64,"))
        let live: Int = try #require(await session.canvas.evaluateInBridge(
            "return document.querySelectorAll('img[data-cue-element=\"image\"]').length") as? Int)
        #expect(live == 1, "the image shows on the slide without a reload")
        await session.undo()
        #expect(session.document.source == original)
    }

    @Test func nudgesMergeIntoOneUndoStep() async throws {
        let harness = try await open()
        defer { harness.close() }
        let session = harness.session
        let original = session.document.source
        let heading = try #require(session.document.heading(onSlide: 2))
        _ = await session.click(at: try await harness.centre(of: heading.cueID))
        for _ in 0..<4 { await session.nudge(dx: 10, dy: 0) }
        #expect(session.document.history.undoCount == 1)
        #expect(session.document.source.contains("translate: 40px 0px"))
        await session.undo()
        #expect(session.document.source == original)
    }
}

/// "hold up." on slide 1 is an inline <font> inside the heading. Inline
/// pieces can't be moved on their own (CSS offsets don't apply to them), so
/// a click on them selects the text box, and moving that moves the text.
@Suite("Clicking inline text", .serialized)
@MainActor
struct InlineTextSelectionTests {
    @Test func clickingInlineTextSelectsAndMovesItsTextBox() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        defer { harness.close() }
        try await harness.load(slide: 0)
        let font = try #require(document.sourceMap.elements.first {
            $0.tag == "font" && $0.path.starts(with: document.structure.slides[0].elementPath)
        })
        let point = try await harness.centre(of: font.cueID)
        let selected = try #require(await harness.session.click(at: point))
        #expect(selected.element.tag != "font", "selects the block the inline text sits in")
        #expect(font.path.starts(with: selected.element.path))

        let textBefore = try #require(try await harness.centre(of: font.cueID) as CGPoint?)
        await harness.session.nudge(dx: 40, dy: 0)
        let textAfter = try await harness.centre(of: font.cueID)
        #expect(textAfter.x > textBefore.x + 1, "the text itself moved")
    }

    @Test func editingFormattedTextWithoutTypingChangesNothing() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        defer { harness.close() }
        try await harness.load(slide: 0)
        let original = harness.session.document.source
        let font = try #require(document.sourceMap.elements.first {
            $0.tag == "font" && $0.path.starts(with: document.structure.slides[0].elementPath)
        })
        await harness.session.doubleClick(at: try await harness.centre(of: font.cueID))
        #expect(harness.session.inlineEdit != nil, "formatted text is editable in place")
        await harness.session.finishInteractions()
        #expect(harness.session.document.source == original)
        #expect(!harness.session.isDirty)
    }
}

/// Clicking the slide's background, or the grey around it, deselects.
@Suite("Clicking the background", .serialized)
@MainActor
struct BackgroundClickTests {
    @Test func clickingEmptySlideAreaOrOutsideDeselects() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        defer { harness.close() }
        try await harness.load(slide: 1)
        let heading = try #require(document.heading(onSlide: 1))
        _ = await harness.session.click(at: try await harness.centre(of: heading.cueID))
        #expect(harness.session.selection != nil)

        // Slide 2's lower right is empty: just the slide's own background.
        let geometry = try #require(await harness.session.canvasGeometry())
        let empty = geometry.viewRect(fromCanvas: CGRect(x: 1840, y: 1000, width: 1, height: 1)).origin
        #expect(await harness.session.click(at: empty) == nil)
        #expect(harness.session.selection == nil, "the slide's background deselects")

        _ = await harness.session.click(at: try await harness.centre(of: heading.cueID))
        #expect(harness.session.selection != nil)
        let outside = geometry.viewRect(fromCanvas: CGRect(x: -40, y: 540, width: 1, height: 1)).origin
        _ = await harness.session.click(at: outside)
        #expect(harness.session.selection == nil, "the area around the slide deselects")
    }
}
