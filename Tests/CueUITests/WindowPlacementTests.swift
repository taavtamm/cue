import CoreGraphics
import Testing
@testable import CueUI

@Suite("Window placement")
struct WindowPlacementTests {
    @Test func centresInTheVisibleFrame() {
        let screen = CGRect(x: 0, y: 80, width: 1728, height: 1000)
        let frame = WindowPlacement.centred(CGSize(width: 920, height: 560), in: screen)
        #expect(frame.size == CGSize(width: 920, height: 560))
        #expect(frame.midX == screen.midX && frame.midY == screen.midY)
    }

    @Test func clampsToSmallScreensWithAMargin() {
        let small = CGRect(x: 0, y: 0, width: 800, height: 500)
        let minimum = CGSize(width: 760, height: 460), wanted = CGSize(width: 920, height: 560)
        let frame = WindowPlacement.centred(wanted, in: small, minimum: minimum)
        #expect(small.contains(frame))
        #expect(frame.width == 760 && frame.height == 460) // Minimum still fits.
        let tiny = CGRect(x: 0, y: 0, width: 600, height: 400)
        let squeezed = WindowPlacement.centred(wanted, in: tiny, minimum: minimum)
        #expect(tiny.contains(squeezed) && squeezed.width == 560 && squeezed.height == 360)
    }

    @Test func worksOnScreensLeftOfOrAboveTheMainOne() {
        let left = CGRect(x: -2560, y: 200, width: 2560, height: 1400)
        let frame = WindowPlacement.centred(CGSize(width: 860, height: 600), in: left)
        #expect(left.contains(frame))
        #expect(abs(frame.midX - left.midX) <= 0.5 && abs(frame.midY - left.midY) <= 0.5)
    }
}
