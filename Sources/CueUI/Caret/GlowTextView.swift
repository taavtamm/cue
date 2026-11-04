import AppKit

/// An NSTextView that never shows the system caret. Its owner draws the
/// glowing caret instead, at `insertionRect()`. Since macOS 14 the system
/// caret is an `NSTextInsertionIndicator` subview; it is forced hidden as
/// soon as AppKit adds it, and `insertionPointColor` is clear as a backstop.
public final class GlowTextView: NSTextView {
    var placeholder = "" { didSet { needsDisplay = true } }
    var placeholderColor = NSColor.white.withAlphaComponent(0.62)

    /// Selection moved, text changed, or layout changed: move the caret.
    var onCaretChange: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    func configure(style: GlowTextStyle) {
        font = style.font
        textColor = NSColor(srgbRed: 245 / 255, green: 245 / 255, blue: 247 / 255, alpha: 1)
        insertionPointColor = .clear
        drawsBackground = false
        isRichText = false
        allowsUndo = true
        focusRingType = .none
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        textContainerInset = .zero
        textContainer?.lineFragmentPadding = 0
        selectedTextAttributes = [.backgroundColor: NSColor(srgbRed: 120 / 255, green: 160 / 255, blue: 1, alpha: 0.35)]
        var typing = typingAttributes
        typing[.kern] = style.kerning
        typingAttributes = typing
        if style.isSingleLine {
            isHorizontallyResizable = true
            textContainer?.widthTracksTextView = false
            textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: style.lineHeight)
            textContainer?.maximumNumberOfLines = 1
        }
        hideSystemIndicators()
    }

    // MARK: Hiding the system caret

    override public func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        hide(subview)
    }

    override public func layout() {
        super.layout()
        hideSystemIndicators()
        onCaretChange?()
    }

    override public func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {}

    /// The system indicators currently in the view. Exposed for tests.
    var systemIndicators: [NSTextInsertionIndicator] {
        subviews.compactMap { $0 as? NSTextInsertionIndicator }
    }

    private func hideSystemIndicators() {
        subviews.forEach(hide)
    }

    private func hide(_ view: NSView) {
        guard let indicator = view as? NSTextInsertionIndicator else { return }
        indicator.displayMode = .hidden
    }

    // MARK: Events

    override public func setSelectedRanges(
        _ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting: Bool
    ) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)
        onCaretChange?()
    }

    override public func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override public func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned { onFocusChange?(false) }
        return resigned
    }

    // MARK: Caret geometry

    var hasRangedSelection: Bool { selectedRange().length > 0 }

    /// The insertion point in this view's coordinates, one line tall.
    func insertionRect() -> CGRect {
        let location = selectedRange().location
        let fallbackHeight = ceil((font?.ascender ?? 12) - (font?.descender ?? -3))
        let origin = textContainerOrigin
        guard let window else { return CGRect(x: origin.x, y: origin.y, width: 0, height: fallbackHeight) }

        let screenRect = firstRect(forCharacterRange: NSRange(location: location, length: 0), actualRange: nil)
        guard screenRect.height > 0 else {
            return CGRect(x: origin.x, y: origin.y, width: 0, height: fallbackHeight)
        }
        let windowRect = window.convertFromScreen(screenRect)
        return convert(windowRect, from: nil)
    }

    // MARK: Placeholder

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty, let font else { return }
        // The caret sits before the placeholder, as in the designs.
        let caretGap: CGFloat = 3
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: placeholderColor, .kern: typingAttributes[.kern] ?? 0,
        ]
        let origin = NSPoint(x: textContainerOrigin.x + caretGap, y: textContainerOrigin.y)
        (placeholder as NSString).draw(at: origin, withAttributes: attributes)
    }
}
