import AppKit

/// AppKit glass for windows and panels that SwiftUI doesn't own, such as
/// the non-activating Launcher panel. Wraps `NSGlassEffectView` and adds
/// Cue's hairline border.
public final class GlassHostingView: NSView {
    private let glass = NSGlassEffectView()
    private let border = CALayer()

    public var contentView: NSView? {
        get { glass.contentView }
        set { glass.contentView = newValue }
    }

    public init(cornerRadius: CGFloat = 28) {
        super.init(frame: .zero)
        wantsLayer = true
        glass.cornerRadius = cornerRadius
        glass.tintColor = NSColor(red: 20 / 255, green: 20 / 255, blue: 24 / 255, alpha: 0.66)
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        border.borderColor = NSColor.white.withAlphaComponent(0.10).cgColor
        border.borderWidth = 1
        border.cornerRadius = cornerRadius
        border.cornerCurve = .continuous
        layer?.addSublayer(border)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override public func layout() {
        super.layout()
        border.frame = bounds
    }
}
