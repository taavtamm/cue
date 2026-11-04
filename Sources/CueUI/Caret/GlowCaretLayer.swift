import AppKit
import QuartzCore

/// The glowing caret as two layers: a bloom (soft haze plus warm glows) and
/// a super-bright core bar. Set `frame` to the insertion rect (bar width ×
/// line height); the glow draws outside it and must never be clipped, so
/// put this layer in a container that doesn't mask to bounds.
///
/// The bloom uses screen blending so only nearby glyphs light up. The host
/// view must set `layerUsesCoreImageFilters = true` for that to apply.
public final class GlowCaretLayer: CALayer {
    public var caretStyle: CaretStyle = .standard { didSet { setNeedsLayout() } }

    /// Glow and haze, pre-rendered by `CaretBloomRenderer`.
    private let bloom = CALayer()
    private let core = CAGradientLayer()

    override public init() {
        super.init()
        setUp()
    }

    override public init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func setUp() {
        masksToBounds = false
        bloom.compositingFilter = "screenBlendMode"
        addSublayer(bloom)

        core.colors = Self.coreColors(headroom: 1)
        core.locations = [0, 0.18, 0.82, 1]
        core.contentsFormat = .RGBA16Float
        core.preferredDynamicRange = .high
        addSublayer(core)

        for layer in [self, bloom, core] { layer.actions = Self.noAnimations }
    }

    /// Lets the core read brighter than surrounding white text on EDR displays.
    /// `headroom` is the screen's current maximum EDR component value.
    public func applyEDR(headroom: CGFloat) {
        core.colors = Self.coreColors(headroom: min(max(headroom, 1), 1.8))
    }

    override public func layoutSublayers() {
        super.layoutSublayers()
        let bar = bounds
        // Gradients are written top to bottom. Flip when this layer is y-up.
        let topIsZero = contentsAreFlipped()
        core.frame = bar
        core.cornerRadius = bar.width / 2
        core.startPoint = CGPoint(x: 0.5, y: topIsZero ? 0 : 1)
        core.endPoint = CGPoint(x: 0.5, y: topIsZero ? 1 : 0)

        let margin = CaretBloomRenderer.margin(for: caretStyle)
        bloom.frame = bar.insetBy(dx: -margin, dy: -margin)
        bloom.contentsScale = contentsScale
        bloom.contentsGravity = .resize
        guard bar.width > 0, bar.height > 0 else { return }
        bloom.contents = CaretBloomRenderer.image(barSize: bar.size, scale: contentsScale, style: caretStyle)
    }

    // MARK: Blink

    /// Applies a presentation from `CaretBlinkPolicy`.
    public func present(_ presentation: CaretBlinkPolicy.Presentation) {
        removeAnimation(forKey: "blink")
        switch presentation {
        case .hidden:
            opacity = 0
        case .solid:
            opacity = 1
        case .blinking:
            opacity = 1
            add(Self.blinkAnimation(), forKey: "blink")
        }
    }

    static func blinkAnimation() -> CAKeyframeAnimation {
        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = CaretBlinkPolicy.keyValues
        blink.keyTimes = CaretBlinkPolicy.keyTimes.map { NSNumber(value: $0) }
        blink.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: CaretBlinkPolicy.keyTimes.count - 1
        )
        blink.duration = CaretBlinkPolicy.period
        blink.repeatCount = .infinity
        blink.beginTime = CACurrentMediaTime()
        return blink
    }

    private nonisolated(unsafe) static let noAnimations: [String: any CAAction] = [
        "position": NSNull(), "bounds": NSNull(), "frame": NSNull(), "opacity": NSNull(),
        "hidden": NSNull(), "contents": NSNull(), "sublayers": NSNull(),
    ]

    private static func coreColors(headroom: CGFloat) -> [CGColor] {
        let space = CGColorSpace(name: CGColorSpace.extendedSRGB)!
        func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
            CGColor(colorSpace: space, components: [r * headroom, g * headroom, b * headroom, 1])!
        }
        // Faint pink (#ffe6f4) at the top, faint cyan (#e6f7ff) at the bottom.
        return [color(1, 0.902, 0.957), color(1, 1, 1), color(1, 1, 1), color(0.902, 0.969, 1)]
    }
}
