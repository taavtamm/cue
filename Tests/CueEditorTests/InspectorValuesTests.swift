import CoreGraphics
import CueEditor
import CueRender
import Testing

@Suite("Inspector values and field input")
struct InspectorValuesTests {
    static let headline = ElementInspection(
        frame: .zero, canvasFrame: CGRect(x: 128.4, y: 151.6, width: 900, height: 96),
        computedStyle: [
            "font-family": "\"Inter Display\", Inter, sans-serif", "font-weight": "600", "font-size": "88px",
            "line-height": "91.52px", "letter-spacing": "-1.76px", "color": "rgb(20, 20, 20)",
        ],
        buildStep: 0, isLeaf: true
    )

    @Test func formatsComputedStyleTheWayTheDesignShowsIt() {
        let values = InspectorValues(inspection: Self.headline)
        #expect(values.fontFamily == "Inter Display")
        #expect(values.fontWeight == "Semibold")
        #expect(values.fontSize == "88")
        #expect(values.lineHeight == "1.04")
        #expect(values.tracking == "-2%")
        #expect(values.color == "#141414")
        #expect([values.x, values.y, values.width, values.height] == ["128", "152", "900", "96"])
    }

    @Test func normalLineHeightAndTranslucentColours() {
        let inspection = ElementInspection(
            frame: .zero, canvasFrame: .zero,
            computedStyle: ["font-size": "20px", "line-height": "normal", "letter-spacing": "normal",
                            "color": "rgba(255, 255, 255, 0.6)"],
            buildStep: nil, isLeaf: true
        )
        let values = InspectorValues(inspection: inspection)
        #expect(values.lineHeight == "Auto")
        #expect(values.tracking == "0%")
        #expect(values.color == "#FFFFFF · 60%")
    }

    @Test func fieldInputBecomesCSS() {
        #expect(StyleInput.cssValue("88", for: .fontSize) == "88px")
        #expect(StyleInput.cssValue("4rem", for: .fontSize) == "4rem")
        #expect(StyleInput.cssValue("-2%", for: .tracking) == "-0.02em")
        #expect(StyleInput.cssValue("auto", for: .lineHeight) == "normal")
        #expect(StyleInput.cssValue("1.1", for: .lineHeight) == "1.1")
        #expect(StyleInput.cssValue("#2f7bff", for: .color) == "#2f7bff")
        #expect(StyleInput.cssValue("2f7bff", for: .color) == "#2f7bff")
    }

    @Test func nonsenseIsRefusedRatherThanWritten() {
        #expect(StyleInput.cssValue("big", for: .fontSize) == nil)
        #expect(StyleInput.cssValue("", for: .width) == nil)
        #expect(StyleInput.cssValue("#12345", for: .color) == nil)
        #expect(StyleInput.cssValue("red; display:none", for: .color) == nil)
    }
}

@Suite("Timeline layout")
struct TimelineLayoutTests {
    @Test func barsArePlacedByFractionsOfTheSpan() {
        let layout = TimelineLayout(SlideAnimations(tracks: [
            .init(name: "fadeUp", target: "Headline", delay: 0, duration: 0.5, iterations: 1, easing: "ease"),
            .init(name: "pulse", target: "Dot", delay: 1, duration: 2, iterations: -1, easing: "linear"),
        ], embedCount: 1))
        #expect(layout.span == 4)
        #expect(layout.rows.count == 2) // Embeds get no track.
        #expect(layout.rows[0].start == 0 && layout.rows[0].width == 0.125)
        #expect(layout.rows[1].loops && layout.rows[1].start == 0.25 && layout.rows[1].width == 0.75)
        #expect(layout.ticks == [0, 1, 2, 3, 4])
    }

    @Test func longAnimationsWidenTheSpan() {
        let layout = TimelineLayout(SlideAnimations(tracks: [
            .init(name: "slow", target: "", delay: 2, duration: 4.2, iterations: 1, easing: "linear"),
        ], embedCount: 0))
        #expect(layout.span == 7)
    }
}
