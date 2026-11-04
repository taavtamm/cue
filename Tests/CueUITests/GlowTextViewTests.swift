import AppKit
import Testing
@testable import CueUI

@Suite("Glow text view")
@MainActor
struct GlowTextViewTests {
    private func makeEditor(_ style: GlowTextStyle = .ask) -> (NSWindow, GlowTextEditorView) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: [.titled], backing: .buffered, defer: false)
        let editor = GlowTextEditorView(style: style)
        editor.frame = NSRect(x: 0, y: 0, width: 400, height: 40)
        window.contentView?.addSubview(editor)
        editor.layoutSubtreeIfNeeded()
        return (window, editor)
    }

    @Test func systemCaretIsNeverVisible() {
        let (window, editor) = makeEditor()
        window.makeFirstResponder(editor.textView)
        editor.textView.insertText("Hello", replacementRange: NSRange(location: 0, length: 0))
        editor.textView.layoutSubtreeIfNeeded()
        #expect(editor.textView.insertionPointColor == .clear)
        #expect(editor.textView.systemIndicators.allSatisfy { $0.displayMode == .hidden })
    }

    @Test func caretFollowsTyping() {
        let (window, editor) = makeEditor()
        window.makeFirstResponder(editor.textView)
        let before = editor.caretOverlay.caret.frame.minX
        editor.textView.insertText("Tighten the headline", replacementRange: NSRange(location: 0, length: 0))
        editor.layout()
        #expect(editor.caretOverlay.caret.frame.minX > before + 50)
        #expect(editor.caretOverlay.caret.frame.height > 10)
    }

    @Test func caretHiddenForRangedSelection() {
        let (window, editor) = makeEditor()
        window.makeFirstResponder(editor.textView)
        editor.textView.insertText("Select me", replacementRange: NSRange(location: 0, length: 0))
        editor.textView.setSelectedRange(NSRange(location: 0, length: 6))
        #expect(editor.caretOverlay.presentation == .hidden)
    }

    @Test func largeStyleUsesThreePointCaret() {
        let (_, editor) = makeEditor(.launcher)
        #expect(editor.caretOverlay.style.barWidth == 3)
    }
}
