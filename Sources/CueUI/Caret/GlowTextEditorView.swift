import AppKit

/// A text input with the glowing caret: a scroll view holding a
/// `GlowTextView`, and a `CaretOverlayView` above it that is never clipped
/// to the field, so the glow can spill past the edges.
public final class GlowTextEditorView: NSView {
    public let textView = GlowTextView()
    public let caretOverlay = CaretOverlayView()
    private let scrollView = NSScrollView()
    public private(set) var style: GlowTextStyle

    public init(style: GlowTextStyle) {
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        buildScrollView()
        textView.configure(style: style)
        caretOverlay.style = style.caret
        addSubview(scrollView)
        addSubview(caretOverlay)
        wireEvents()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override public var isFlipped: Bool { true }

    override public var intrinsicContentSize: NSSize {
        let height = style.isSingleLine ? style.lineHeight : NSView.noIntrinsicMetric
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }

    private func buildScrollView() {
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = !style.isSingleLine
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = textView
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = !style.isSingleLine
        textView.autoresizingMask = style.isSingleLine ? [] : [.width]
        scrollView.contentView.postsBoundsChangedNotifications = true
    }

    private func wireEvents() {
        textView.onCaretChange = { [weak self] in self?.updateCaret() }
        textView.onFocusChange = { [weak self] _ in self?.updateFocus() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(contentScrolled),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(textEdited),
            name: NSText.didChangeNotification, object: textView
        )
    }

    /// The caret blinks only in the key window: a field left focused in a
    /// background window shows nothing and costs nothing.
    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        center.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        center.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        guard let window else { return }
        center.addObserver(self, selector: #selector(windowKeyChanged), name: NSWindow.didBecomeKeyNotification, object: window)
        center.addObserver(self, selector: #selector(windowKeyChanged), name: NSWindow.didResignKeyNotification, object: window)
        updateFocus()
    }

    @objc private func windowKeyChanged() { updateFocus() }

    private func updateFocus() {
        let focused = window?.firstResponder === textView && window?.isKeyWindow == true
        caretOverlay.setFocused(focused)
        updateCaret()
    }

    override public func layout() {
        super.layout()
        let height = style.isSingleLine ? style.lineHeight : bounds.height
        let y = style.isSingleLine ? (bounds.height - height) / 2 : 0
        scrollView.frame = CGRect(x: 0, y: y, width: bounds.width, height: height)
        caretOverlay.frame = bounds
        if style.isSingleLine {
            let width = max(bounds.width, textView.frame.width)
            textView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        } else {
            textView.frame.size.width = scrollView.contentSize.width
        }
        updateCaret()
    }

    /// Puts the caret at the insertion point, hides it for ranged selections.
    func updateCaret() {
        caretOverlay.setRangedSelection(textView.hasRangedSelection)
        let rect = convert(textView.insertionRect(), from: textView)
        caretOverlay.moveCaret(to: rect)
        if style.isSingleLine { scrollCaretIntoView() }
    }

    private func scrollCaretIntoView() {
        textView.scrollRangeToVisible(textView.selectedRange())
    }

    @objc private func contentScrolled() { updateCaret() }

    @objc private func textEdited() {
        caretOverlay.noteEdit()
        if style.isSingleLine { textView.sizeToFit() }
        updateCaret()
    }
}
