import CueCore
import Foundation
import MCP
import Testing
@testable import CueMCP

@Suite("Cue's MCP tools")
struct ToolTests {
    @Test func listsToolsAndResources() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let tools = try await mcp.client.listTools().tools.map(\.name)
        for name in ["get_outline", "get_slide_html", "get_selection", "render_slide", "edit_element", "replace_slide_html",
                     "add_slide", "delete_slide", "move_slide", "set_notes", "set_builds", "insert_text_box",
                     "insert_image", "insert_shape", "move_element", "resize_element", "list_changes", "accept_change",
                     "revert_change", "next_request", "complete_request"] {
            #expect(tools.contains(name), "missing \(name)")
        }
        let resources = try await mcp.client.listResources().resources.map(\.uri)
        #expect(resources.contains("cue://deck/outline") && resources.contains("cue://editor/selection"))
        let slide = try await mcp.client.readResource(uri: "cue://deck/slide/2/html")
        #expect(slide.first?.text?.contains("Second") == true)
    }

    @Test func outlineAndSlideHTML() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let outline = try await mcp.call("get_outline")
        #expect(!outline.isError && outline.text.contains("\"number\" : 3") && outline.text.contains("Hello"))
        let html = try await mcp.call("get_slide_html", ["slide": 3])
        #expect(html.text.hasPrefix("<section") && html.text.contains("Q3 results"))
        let missing = try await mcp.call("get_slide_html", ["slide": 9])
        #expect(missing.isError && missing.text.contains("has 3 slides"))
    }

    /// The brief's test, headless: "make slide 3's headline shorter".
    @Test func editsLandAsChangeSetsAndAreNotSaved() async throws {
        let (document, url) = try Decks.document()
        let host = FakeHost(document)
        let mcp = try await MCPHarness.connect(host)
        let reply = try await mcp.call("edit_element", [
            "target": ["slide": 3, "selector": "h1.headline"], "text": "Q3 beat expectations",
            "summary": "Shorter headline",
        ])
        #expect(!reply.isError, "\(reply.text)")
        let id = try #require(MCPHarness.changeID(reply.text))
        #expect(reply.text.contains("pending") && reply.text.contains("Our Q3 results"))
        #expect(await host.document.source.contains("Q3 beat expectations"))
        #expect(try String(contentsOf: url, encoding: .utf8) == Decks.small, "nothing saved")

        let list = try await mcp.call("list_changes")
        #expect(list.text.contains(id))
        let undo = try await mcp.call("revert_change", ["id": .string(id)])
        #expect(!undo.isError)
        #expect(await host.document.source == Decks.small)
    }

    @Test func selectorsMustBeUnambiguous() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let ambiguous = try await mcp.call("edit_element", ["target": ["slide": 2, "selector": "p"], "text": "x"])
        #expect(ambiguous.isError && ambiguous.text.contains("matches 2"))
        let picked = try await mcp.call("edit_element", ["target": ["slide": 2, "selector": "p", "index": 1], "text": "x"])
        #expect(!picked.isError)
    }

    @Test func structureNotesStylesAndInserts() async throws {
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        let mcp = try await MCPHarness.connect(host)
        #expect(!(try await mcp.call("set_notes", ["slide": 2, "text": "Pause here"])).isError)
        #expect(!(try await mcp.call("edit_element", ["target": ["slide": 1, "selector": "h1"],
                                                       "style": ["color": "red"]])).isError)
        #expect(!(try await mcp.call("insert_text_box", ["slide": 2, "text": "New box", "x": 100, "y": 200])).isError)
        #expect(!(try await mcp.call("insert_shape", ["slide": 1, "shape": "ellipse"])).isError)
        #expect(!(try await mcp.call("move_slide", ["slide": 3, "to": 1])).isError)
        #expect(!(try await mcp.call("add_slide", ["after": 3])).isError)
        let source = await host.document.source
        #expect(source.contains("Pause here") && source.contains("color: red") && source.contains("New box"))
        #expect(await host.document.structure.slides.count == 4)
        #expect(await host.document.structure.slides.first?.id == "end")
        let badShape = try await mcp.call("insert_shape", ["slide": 1, "shape": "star"])
        #expect(badShape.isError)
    }

    @Test func imagesComeFromTheDeckFolderOnly() async throws {
        let (document, url) = try Decks.document()
        let folder = url.deletingLastPathComponent()
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: folder.appending(path: "logo.png"))
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let inside = try await mcp.call("insert_image", ["slide": 1, "source": "logo.png", "description": "Logo"])
        #expect(!inside.isError, "\(inside.text)")
        let outside = try await mcp.call("insert_image", ["slide": 1, "source": "/etc/hosts.png", "description": "x"])
        #expect(outside.isError && outside.text.contains("inside the deck's folder"))
        let escape = try await mcp.call("insert_image", ["slide": 1, "source": "../secret.png", "description": "x"])
        #expect(escape.isError)
    }

    @Test func renderReturnsAnImage() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let (content, isError) = try await mcp.client.callTool(name: "render_slide", arguments: ["slide": 1])
        #expect(isError != true)
        guard case .image(_, let type, _, _)? = content.first else { Issue.record("no image"); return }
        #expect(type == "image/png")
    }

    @Test func unapprovedClientsWaitForTheUser() async throws {
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        await host.setDecision(.pending)
        let mcp = try await MCPHarness.connect(host, name: "claude-desktop")
        let waiting = try await mcp.call("get_outline")
        #expect(waiting.isError && waiting.text.contains("Waiting for approval in Cue") && waiting.text.contains("claude-desktop"))
        await host.setDecision(.denied)
        #expect(try await mcp.call("get_outline").text.contains("doesn't allow"))
        await host.setDecision(.approved)
        #expect(!(try await mcp.call("get_outline")).isError)
    }
}
