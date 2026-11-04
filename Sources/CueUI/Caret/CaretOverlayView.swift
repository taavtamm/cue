import AppKit

/// A transparent, click-through view that draws the glowing caret at any
/// rect. Text views feed it their insertion rect; the slide editor will feed
/// it rects from the web view's Selection API. It owns the blink state:
/// solid while typing and for a moment after, hidden for ranged selections.
public final class CaretOverlayView: NSView {
    public let caret = GlowCaretLayer()

    public var style: CaretStyle {
        get { caret.caretStyle }
        set { caret.caretStyle = newValue }
    }

    private var isFocused = false
    private var hasRangedSelection = false
    private var lastEdit: Date?
    private var resumeBlink: DispatchWorkItem?
    private var currentPresentation: CaretBlinkPolicy.Presentation?

    /// Injected so tests can control Reduce Motion.
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerUsesCoreImageFilters = true
        layer?.masksToBounds = false
        layer?.addSublayer(caret)
        caret.present(.hidden)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(displayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override public var isFlipped: Bool { true }
    override public func hitTest(_ point: NSPoint) -> NSView? { nil }

    override public func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        caret.contentsScale = window?.backingScaleFactor ?? 2
        caret.applyEDR(headroom: window?.screen?.maximumExtendedDynamicRangeColorComponentValue ?? 1)
    }

    // MARK: Inputs

    /// Moves the caret. `rect` is in this view's coordinates; its height is
    /// the line height. Only x, y and height are used; width comes from style.
    public func moveCaret(to rect: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let width = style.barWidth
        caret.frame = CGRect(x: rect.minX - width / 2, y: rect.minY, width: width, height: rect.height)
        // Lay out now so the bloom never trails the bar by a frame.
        caret.layoutIfNeeded()
        CATransaction.commit()
    }

    public func setFocused(_ focused: Bool) {
        isFocused = focused
        refresh()
    }

    public func setRangedSelection(_ ranged: Bool) {
        hasRangedSelection = ranged
        refresh()
    }

    /// Call on every keystroke. Holds the caret solid, then resumes blinking.
    public func noteEdit() {
        lastEdit = Date()
        refresh()
        resumeBlink?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        resumeBlink = work
        DispatchQueue.main.asyncAfter(deadline: .now() + CaretBlinkPolicy.typingHold + 0.01, execute: work)
    }

    var presentation: CaretBlinkPolicy.Presentation {
        CaretBlinkPolicy.presentation(
            isFocused: isFocused,
            hasRangedSelection: hasRangedSelection,
            secondsSinceEdit: lastEdit.map { Date().timeIntervalSince($0) },
            reduceMotion: reduceMotion()
        )
    }

    func refresh() {
        let next = presentation
        // Re-adding the blink would restart its phase; only react to changes.
        guard next != currentPresentation else { return }
        currentPresentation = next
        caret.present(next)
    }

    @objc private func displayOptionsChanged() {
        currentPresentation = nil
        refresh()
    }
}
