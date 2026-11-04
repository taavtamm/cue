import AppKit
import CueCore
import CueEditor
import CueUI
import SwiftUI
import UniformTypeIdentifiers

/// The toolbar's Insert menu: a text box, an image, or a basic shape.
/// ⌥⌘T and ⌥⌘I also work on the canvas (see `CanvasContainerView+Zoom`).
struct InsertMenu: View {
    let session: EditorSession

    var body: some View {
        Menu {
            Button("Text Box  ⌥⌘T") { EditorInsert.textBox(session) }
            Button("Image…  ⌥⌘I") { EditorInsert.chooseImage(session) }
            Divider()
            ForEach(ElementTemplate.Shape.allCases, id: \.self) { shape in
                Button(shape.title) { Task { await session.insert(.shape(shape)) } }
            }
        } label: {
            Image(systemName: "square.on.circle").font(.system(size: 16))
                .frame(width: 36, height: 34)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Insert a text box, image or shape")
        .accessibilityLabel("Insert")
    }
}

/// Inserting from menus and shortcuts.
@MainActor
enum EditorInsert {
    static func textBox(_ session: EditorSession) {
        Task {
            if await session.insert(.textBox(text: "Text", fontSize: 64, fontFamily: nil)) {
                await session.beginInlineEdit() // Type straight away.
            }
        }
    }

    static func chooseImage(_ session: EditorSession) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Images are embedded in the deck, so it stays one file."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await session.insertImage(contentsOf: url) }
    }
}
