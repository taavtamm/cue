import CueEditor
import CueUI
import SwiftUI

/// The current slide's HTML, scrolled to the selected element. Read-only
/// for now: editing HTML directly comes in a later milestone. Long data:
/// URLs (inline images) are shortened here so the markup stays readable.
struct HTMLSourcePanel: View {
    let session: EditorSession
    @Environment(\.isSnapshotRendering) private var isSnapshot

    var body: some View {
        let excerpt = SourceExcerpt(session: session)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(excerpt.title).font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("Read-only · editing HTML directly comes later")
                    .font(.system(size: 11.5)).foregroundStyle(CueTheme.textTertiary)
            }
            Group {
                if isSnapshot { // ImageRenderer can't draw the AppKit code view.
                    Text(excerpt.text.prefix(4_000)).font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(12).clipped()
                } else {
                    SourceCodeView(text: excerpt.text, highlight: excerpt.highlight)
                }
            }
                .background(CueTheme.insetFill, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.07)))
        }
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

/// A read-only code view in SF Mono with Cue's caret styling.
private struct SourceCodeView: NSViewRepresentable {
    let text: String
    let highlight: NSRange?

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        let editor = GlowTextEditorView(style: .code)
        editor.textView.isEditable = false
        editor.textView.isSelectable = true
        scroll.documentView = editor.textView
        editor.textView.isVerticallyResizable = true
        editor.textView.textContainerInset = CGSize(width: 12, height: 12)
        editor.textView.autoresizingMask = [.width]
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != text { textView.string = text }
        if let highlight, NSMaxRange(highlight) <= (text as NSString).length {
            textView.setSelectedRange(highlight)
            textView.scrollRangeToVisible(highlight)
        }
    }
}
