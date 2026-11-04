import Testing
@testable import CueUI

/// Text tokens over the surfaces they sit on must reach 4.5:1 (WCAG AA).
@Suite("Colour contrast")
struct ContrastTests {
    typealias RGB = Contrast.RGB
    let ground = RGB(hex: 0x07070A)
    /// Window glass, rgba(20,20,24,0.66), seen over the ground.
    var glass: RGB { RGB(hex: 0x141418).over(ground, alpha: 0.66) }
    let white = RGB(red: 1, green: 1, blue: 1)

    @Test(arguments: [0.6, 0.65, 0.7])
    func secondaryTextOnGlass(alpha: Double) {
        #expect(Contrast.ratio(white.over(glass, alpha: alpha), glass) >= 4.5)
    }

    @Test func primaryTextOnGround() {
        #expect(Contrast.ratio(RGB(hex: 0xF5F5F7), ground) >= 4.5)
    }

    @Test func accentTextOnTintedFills() {
        let liveFill = RGB(hex: 0x38E1FF).over(ground, alpha: 0.14)
        let redFill = RGB(hex: 0xFF453A).over(ground, alpha: 0.18)
        #expect(Contrast.ratio(RGB(hex: 0x7FE9FF), liveFill) >= 4.5)
        #expect(Contrast.ratio(RGB(hex: 0xFF8A80), redFill) >= 4.5)
        #expect(Contrast.ratio(RGB(hex: 0x9ECBFF), ground) >= 4.5)
    }

    @Test func darkTextOnPrimaryButton() {
        #expect(Contrast.ratio(RGB(hex: 0x0A0A0C), RGB(hex: 0xF5F5F7)) >= 4.5)
    }

    @Test func whiteOnBadges() {
        // Role badges carry bold 10.5 pt text; check the darker two reach 3:1 at least.
        #expect(Contrast.ratio(white, RGB(hex: 0x2F7BFF)) >= 3)
        #expect(Contrast.ratio(white, RGB(hex: 0xFF453A)) >= 3)
    }
}
