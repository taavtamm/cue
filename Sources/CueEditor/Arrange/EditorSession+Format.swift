import AppKit
import Foundation

/// The format bar's commands, applied to the text being edited on the slide.
extension EditorSession {
    public enum TextFormat: String, Sendable {
        case bold, italic, underline, link, lineBreak
    }

    public func format(_ format: TextFormat) async {
        guard inlineEdit != nil else { return }
        switch format {
        case .bold: try? await canvas.formatText("bold")
        case .italic: try? await canvas.formatText("italic")
        case .underline: try? await canvas.formatText("underline")
        case .lineBreak: try? await canvas.formatText("insertLineBreak")
        case .link:
            let copied = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = copied, ["http://", "https://", "mailto:"].contains(where: url.lowercased().hasPrefix) else {
                lastError = "Copy a link (https://…), select the words, then press Link."
                return
            }
            try? await canvas.formatText("createLink", value: url)
        }
    }
}
