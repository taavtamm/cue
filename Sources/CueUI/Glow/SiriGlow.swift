import SwiftUI

/// The rotating multicolour glow from the designs: a 1 px conic ring plus
/// a blurred halo behind any shape. Used on the Ask bar, Play and Start show.
/// With Reduce Motion on, the gradient holds still.
public struct SiriGlow<S: Shape>: View {
    let shape: S
    var ringWidth: CGFloat = 1
    var haloBlur: CGFloat = 12
    var haloOpacity: Double = 0.55
    var haloSpread: CGFloat = 2
    var showsRing = true
    /// Turns per `CueTheme.siriGlowPeriod`: 1 as designed, more while busy.
    var speed: Double = 1
    /// Holds the gradient still (nothing happening, or Reduce Motion).
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        TimelineView(.animation(paused: reduceMotion || isPaused)) { timeline in
            let still = reduceMotion || isPaused
            let gradient = Self.gradient(angle: Self.angle(at: timeline.date, reduceMotion: still, speed: speed))
            ZStack {
                shape
                    .fill(gradient)
                    .padding(-haloSpread)
                    .blur(radius: haloBlur)
                    .opacity(haloOpacity)
                if showsRing {
                    shape.stroke(gradient, lineWidth: ringWidth)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The gradient's rotation at `date`. One turn per `CueTheme.siriGlowPeriod`.
    /// Reduce Motion pins it at 0°.
    static func angle(at date: Date, reduceMotion: Bool, speed: Double = 1) -> Angle {
        guard !reduceMotion else { return .zero }
        let period = CueTheme.siriGlowPeriod / max(0.1, speed)
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        return .degrees(phase * 360)
    }

    static func gradient(angle: Angle) -> AngularGradient {
        // CSS conic gradients start at 12 o'clock; SwiftUI's start at 3.
        AngularGradient(
            colors: CueTheme.siriGlowColors,
            center: .center,
            angle: angle - .degrees(90)
        )
    }
}

extension SiriGlow {
    public init(
        _ shape: S,
        ringWidth: CGFloat = 1,
        haloBlur: CGFloat = 12,
        haloOpacity: Double = 0.55,
        haloSpread: CGFloat = 2,
        showsRing: Bool = true,
        speed: Double = 1,
        isPaused: Bool = false
    ) {
        self.speed = speed
        self.isPaused = isPaused
        self.shape = shape
        self.ringWidth = ringWidth
        self.haloBlur = haloBlur
        self.haloOpacity = haloOpacity
        self.haloSpread = haloSpread
        self.showsRing = showsRing
    }
}

extension View {
    /// Puts the Siri glow behind this view, following `shape`.
    public func siriGlow<S: Shape>(
        _ shape: S,
        ringWidth: CGFloat = 1,
        haloBlur: CGFloat = 12,
        haloOpacity: Double = 0.55,
        showsRing: Bool = true,
        speed: Double = 1,
        isPaused: Bool = false
    ) -> some View {
        background(
            SiriGlow(shape, ringWidth: ringWidth, haloBlur: haloBlur, haloOpacity: haloOpacity, showsRing: showsRing,
                     speed: speed, isPaused: isPaused)
        )
    }
}

#Preview {
    ZStack {
        CueBackground()
        Text("Ask Cue to change this slide…")
            .foregroundStyle(CueTheme.text)
            .padding(.horizontal, 24)
            .frame(height: 52)
            .background(Color(white: 0.06, opacity: 0.95), in: Capsule())
            .siriGlow(Capsule(), haloBlur: 16)
    }
    .frame(width: 520, height: 200)
}
