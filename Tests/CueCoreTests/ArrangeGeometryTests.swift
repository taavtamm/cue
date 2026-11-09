import CoreGraphics
import Foundation
import Testing
@testable import CueCore

@Suite("Placement and snapping")
struct ArrangeGeometryTests {
    let start = CGRect(x: 100, y: 200, width: 400, height: 100)

    @Test func cueElementsMoveByLeftAndTop() {
        let changes = ElementPlacement.changes(
            from: start, to: start.offsetBy(dx: 30, dy: -20), inlineStyle: "position: absolute; left: 100px; top: 200px",
            isCueElement: true
        )
        #expect(changes == [StyleChange("left", "130px"), StyleChange("top", "180px")])
    }

    @Test func deckElementsMoveByAnOffsetThatAddsUp() {
        let changes = ElementPlacement.changes(
            from: start, to: start.offsetBy(dx: 100, dy: 0), inlineStyle: "translate: 12px 5px", isCueElement: false
        )
        #expect(changes == [StyleChange("translate", "112px 5px")])
        let back = ElementPlacement.changes(
            from: start, to: start.offsetBy(dx: -12, dy: -5), inlineStyle: "translate: 12px 5px", isCueElement: false
        )
        #expect(back == [StyleChange("translate", nil)], "moving back home removes the offset")
    }

    @Test func resizingSetsWidthAndHeight() {
        let resized = ElementPlacement.resized(start, handle: [.right, .bottom], by: CGSize(width: 50, height: 25), keepAspect: false)
        #expect(resized == CGRect(x: 100, y: 200, width: 450, height: 125))
        let changes = ElementPlacement.changes(from: start, to: resized, inlineStyle: "", isCueElement: false)
        #expect(changes == [StyleChange("width", "450px"), StyleChange("height", "125px")])
    }

    @Test func resizingFromTheLeftMovesTheOriginToo() {
        let resized = ElementPlacement.resized(start, handle: .left, by: CGSize(width: -40, height: 0), keepAspect: false)
        #expect(resized.minX == 60 && resized.maxX == start.maxX)
    }

    @Test func shiftKeepsTheAspectRatio() {
        let resized = ElementPlacement.resized(start, handle: [.right, .bottom], by: CGSize(width: 400, height: 0), keepAspect: true)
        #expect(resized.width / resized.height == 4)
    }

    @Test func shiftLocksAMoveToOneAxis() {
        #expect(ElementPlacement.moved(start, by: CGSize(width: 50, height: 8), constrained: true) == start.offsetBy(dx: 50, dy: 0))
    }

    @Test func snapsToTheSlideCentreAndDrawsAGuide() {
        let snapping = Snapping(canvas: CGSize(width: 1920, height: 1080), others: [], threshold: 8)
        let near = CGRect(x: 755, y: 300, width: 400, height: 100) // centre x 955, 5 px from 960
        let (frame, guides) = snapping.snap(moving: near)
        #expect(frame.midX == 960)
        #expect(guides.contains(Snapping.Guide(axis: .vertical, position: 960)))
    }

    @Test func snapsToAnotherBoxEdge() {
        let other = CGRect(x: 1200, y: 600, width: 300, height: 100)
        let snapping = Snapping(canvas: CGSize(width: 1920, height: 1080), others: [other], threshold: 8)
        let (frame, _) = snapping.snap(moving: CGRect(x: 1203, y: 900, width: 200, height: 50))
        #expect(frame.minX == 1200)
    }

    @Test func farAwayDoesNotSnap() {
        let snapping = Snapping(canvas: CGSize(width: 1920, height: 1080), others: [], threshold: 8)
        let rect = CGRect(x: 300, y: 300, width: 100, height: 100)
        #expect(snapping.snap(moving: rect).frame == rect)
        #expect(snapping.snap(moving: rect).guides.isEmpty)
    }

    @Test func portableCopiesArePositionedAndRenamed() throws {
        let copy = try #require(ElementCopy.portable(
            #"<h1 id="title" class="headline" style="color: red; margin: 0 auto">Hi <b>there</b></h1>"#,
            frame: CGRect(x: 10, y: 20, width: 300, height: 80), newID: "cue-copy"
        ))
        let start = #"<h1 id="cue-copy" class="headline" data-cue-element="copy" "#
            + #"style="position: absolute; left: 10px; top: 20px; width: 300px; height: 80px; margin: 0; color: red;">"#
        #expect(copy.hasPrefix(start))
        #expect(copy.hasSuffix("Hi <b>there</b></h1>"))
    }
}

@Suite("Rich text sanitiser")
struct RichTextSanitizerTests {
    @Test func keepsSimpleFormatting() {
        #expect(RichTextSanitizer.sanitize("a <b>b</b> <i>c</i><br><u>d</u>") == "a <b>b</b> <i>c</i><br><u>d</u>")
    }

    @Test func dropsScriptsHandlersAndStyles() {
        let dirty = #"<b onclick="steal()" style="x">hi</b><script>evil()</script><style>p{}</style><!-- c -->ok"#
        #expect(RichTextSanitizer.sanitize(dirty) == "<b>hi</b>ok")
    }

    @Test func keepsSafeLinksOnly() {
        #expect(RichTextSanitizer.sanitize(#"<a href="https://x.y" target="_blank">x</a>"#) == #"<a href="https://x.y">x</a>"#)
        #expect(RichTextSanitizer.sanitize(#"<a href="javascript:alert(1)">x</a>"#) == "<a>x</a>")
    }

    @Test func unknownTagsKeepTheirText() {
        #expect(RichTextSanitizer.sanitize("<blink>red</blink> <img src=x onerror=y>") == "red ")
    }

    /// Editing the demo deck's heading must not strip the grey of "hold up.".
    @Test func keepsTheDecksOwnFormatting() {
        let deck = ##"Plans that <font color="#6a6761" style="color: rgb(106, 103, 97); -webkit-text-fill-color: currentcolor;">hold up.</font>"##
        #expect(RichTextSanitizer.sanitize(deck) == deck)
        #expect(RichTextSanitizer.sanitize(#"<span class="hl" data-text-path="0.1">x</span>"#)
                == #"<span class="hl" data-text-path="0.1">x</span>"#)
    }

    @Test func dropsCuesMarkersAndUnsafeStyles() {
        #expect(RichTextSanitizer.sanitize(#"<b data-cue-id="41" onmouseover="x()">x</b>"#) == "<b>x</b>")
        #expect(RichTextSanitizer.sanitize(#"<span style="color: red; background: url(https://evil/x)">x</span>"#)
                == #"<span style="color: red;">x</span>"#)
    }
}
