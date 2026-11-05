import Foundation
import MCP

/// Tools for working with whole presentations: make a new one, see what's
/// open, switch to another, save. Every other tool works on the target deck.
enum DeckTools {
    static let tools: [Tool] = [
        ToolCatalog.tool("create_deck",
                         "Creates a new presentation, opens it in Cue and makes it the deck every other tool works on. "
                         + "Pass `html` for the whole document (a complete HTML deck: one <section data-cue-slide> per "
                         + "slide, data-cue-notes for notes, a <meta name=\"cue:canvas\" content=\"1920x1080\">), or leave "
                         + "it out for Cue's blank title slide and build it up with the other tools. Saved as "
                         + "“<title>.html” in `folder` (default: the user's save folder) and never over an existing file. "
                         + "This writes a new file at once; later edits stay unsaved until save_deck or the user saves.",
                         ["title": ToolCatalog.string("Presentation title; also the file name."),
                          "html": ToolCatalog.string("Optional complete HTML document for the deck."),
                          "folder": ToolCatalog.string("Optional folder inside the user's home folder.")],
                         ["title"]),
        ToolCatalog.tool("list_decks",
                         "Decks open in Cue (the one tools work on is marked target) and recently opened ones, with paths.",
                         [:], readOnly: true),
        ToolCatalog.tool("open_deck",
                         "Opens a deck in Cue and makes it the target of every other tool. HTML decks open as they are; "
                         + "PowerPoint, Keynote, OpenDocument and PDF are converted to an HTML copy next to the original.",
                         ["path": ToolCatalog.string("Absolute path, e.g. from list_decks.")], ["path"]),
        ToolCatalog.tool("save_deck",
                         "Saves the target deck to its own file. Only when the user asked for it to be saved.",
                         [:]),
    ]
}

extension ToolRunner {
    func deck(_ name: String, _ args: ToolArguments) async throws -> CallTool.Result? {
        switch name {
        case "list_decks":
            return try json(await host.decks())
        case "create_deck":
            let title = try args.requiredString("title")
            let defaultFolder = await host.newDeckFolder()
            let folder = try args.string("folder").map(Self.folderURL) ?? defaultFolder
            let url = try NewDeckLocation.url(title: title, in: folder, home: await host.deckRoot())
            return try json(try await host.createDeck(at: url, title: title, html: args.string("html")))
        case "open_deck":
            let path = (try args.requiredString("path") as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: path) else { throw CueMCPError.invalid("There's no file at \(path).") }
            return try json(try await host.openDeck(URL(filePath: path)))
        case "save_deck":
            return try json(try await host.saveDeck())
        default:
            return nil
        }
    }

    private static func folderURL(_ path: String) throws -> URL {
        URL(filePath: (path as NSString).expandingTildeInPath, directoryHint: .isDirectory)
    }
}
