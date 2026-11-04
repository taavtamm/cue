import SwiftUI

/// Cue's text input for SwiftUI. Use it everywhere instead of `TextField`:
/// it draws the glowing caret and never shows the system one.
///
///     GlowTextField("Ask Cue to change this slide…", text: $ask, style: .ask) { send() }
public struct GlowTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let style: GlowTextStyle
    let onSubmit: (() -> Void)?
    /// Called when the field loses focus, e.g. to commit an inspector value.
    var onEndEditing: (() -> Void)?
    /// False shows the text with the glowing caret but refuses typing.
    var isEditable = true

    public init(
        _ placeholder: String = "",
        text: Binding<String>,
        style: GlowTextStyle = .field,
        isEditable: Bool = true,
        onSubmit: (() -> Void)? = nil,
        onEndEditing: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.style = style
        self.isEditable = isEditable
        self.onSubmit = onSubmit
        self.onEndEditing = onEndEditing
    }

    public func makeNSView(context: Context) -> GlowTextEditorView {
        let editor = GlowTextEditorView(style: style)
        editor.textView.string = text
        editor.textView.placeholder = placeholder
        editor.textView.delegate = context.coordinator
        editor.textView.setAccessibilityLabel(placeholder)
        editor.textView.isEditable = isEditable
        return editor
    }

    public func updateNSView(_ editor: GlowTextEditorView, context: Context) {
        context.coordinator.parent = self
        if editor.textView.string != text { editor.textView.string = text }
        editor.textView.placeholder = placeholder
        editor.textView.isEditable = isEditable
    }

    public func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: GlowTextField
        init(parent: GlowTextField) { self.parent = parent }

        public func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
        }

        public func textDidEndEditing(_ notification: Notification) {
            parent.onEndEditing?()
        }

        public func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard parent.style.isSingleLine, selector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            parent.onSubmit?()
            return true
        }
    }
}

#Preview {
    @Previewable @State var ask = ""
    @Previewable @State var notes = "Speaker notes go here."
    VStack(alignment: .leading, spacing: 20) {
        GlowTextField("Ask Cue to change this slide…", text: $ask, style: .ask).frame(height: 40)
        GlowTextField("Search or Ask", text: $ask, style: .launcher).frame(height: 70)
        GlowTextField(text: $notes, style: .notes).frame(height: 120)
    }
    .padding(32)
    .background(CueTheme.ground)
}
