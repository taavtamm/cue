import CueCore
import CueRender
import Foundation

/// Editing text directly on the slide. The page reports the caret and the
/// final text; the edit itself is an ordinary `setText` patch, so the page
/// ends up showing exactly what the source now says.
extension EditorSession {
    /// Starts editing the selected element's text, if it has no children.
    public func beginInlineEdit() async {
        guard let selection, selection.inspection?.isLeaf == true else { return }
        let started = (try? await canvas.beginTextEditing(cueID: selection.cueID)) ?? false
        if started { inlineEdit = InlineEditState(cueID: selection.cueID, path: selection.path) }
    }

    public func endInlineEdit(commit: Bool) async {
        guard inlineEdit != nil else { return }
        try? await canvas.endTextEditing(commit: commit)
    }

    func handleInlineText(_ event: InlineTextEvent) {
        switch event {
        case .caret(let rect, let collapsed):
            inlineEdit?.caret = canvas.viewRect(fromCSS: rect)
            inlineEdit?.collapsed = collapsed
        case .input(let rect, let collapsed):
            inlineEdit?.caret = canvas.viewRect(fromCSS: rect)
            inlineEdit?.collapsed = collapsed
            inlineEdit?.inputCount += 1
        case .commit(let cueID, let text, let html):
            let path = inlineEdit?.path ?? document.element(cueID: cueID)?.path
            inlineEdit = nil
            guard let path, let element = document.sourceMap.element(at: path) else { return resumeCommitWaiters() }
            Task {
                if let html { await commitMarkup(html, to: element) } else { await commitText(text, to: element) }
                resumeCommitWaiters()
            }
        case .cancel:
            inlineEdit = nil
            resumeCommitWaiters()
        }
    }

    /// Ends embed interaction and inline editing, and returns once the typed
    /// text is in the document. Use before reading the document (e.g. to
    /// present it). Gives up after a second if the page never answers.
    public func finishInteractions() async {
        if inlineEdit != nil {
            await withCheckedContinuation { continuation in
                inlineCommitWaiters.append(continuation)
                Task { try? await canvas.endTextEditing(commit: true) }
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    self.resumeCommitWaiters()
                }
            }
        }
        endInteractions()
        _ = await editChain?.value
    }

    func resumeCommitWaiters() {
        let waiters = inlineCommitWaiters
        inlineCommitWaiters = []
        waiters.forEach { $0.resume() }
    }

    /// A text box with formatting: its sanitised markup replaces its content.
    private func commitMarkup(_ html: String, to element: MappedElement) async {
        let current = element.innerRange.map { (document.source as NSString).substring(with: NSRange(
            location: $0.start, length: $0.length)) }
        if current == RichTextSanitizer.sanitize(html) { return } // Unchanged: no edit, no undo step.
        if await !apply(.setInnerHTML(element.path, html)) {
            try? await loadCanvas()
        }
    }

    private func commitText(_ text: String, to element: MappedElement) async {
        let node = document.tree.node(at: element.path)
        if let original = node?.text, original == text { return } // Unchanged: no edit, no undo step.
        if await !apply(.setText(element.path, text)) {
            try? await loadCanvas() // Refused: put the page back to what the file says.
        }
    }
}
