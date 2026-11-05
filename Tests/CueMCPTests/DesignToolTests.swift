import CoreGraphics
import CueCore
import Foundation
import ImageIO
import MCP
import Testing
import UniformTypeIdentifiers
@testable import CueMCP

/// Deck-wide tools for redesigns, over the in-memory transport.
@Suite("Design tools", .serialized)
struct DesignToolTests {
    private func connect(_ html: String = Decks.small) async throws -> (MCPHarness, FakeHost, String) {
        let (document, _) = try Decks.document(html)
        let host = FakeHost(document)
        return (try await MCPHarness.connect(host), host, document.source)
    }

    @Test func listsTheDesignTools() async throws {
        let (mcp, _, _) = try await connect()
        let tools = try await mcp.client.listTools().tools.map(\.name)
        for name in ["get_styles", "set_deck_style", "set_theme_variables", "add_font", "get_head", "set_head_html",
                     "get_deck_html", "replace_deck_html", "get_embeds", "edit_embed", "set_transition", "render_deck"] {
            #expect(tools.contains(name), "missing \(name)")
        }
    }

    @Test func deckStyleMergesByRuleAndUndoesToTheExactBytes() async throws {
        let (mcp, host, _) = try await connect()
        let first = try await mcp.call("set_deck_style", ["css": ".headline { color: #2f7bff; }\nbody { background: #111; }"])
        #expect(!first.isError, "\(first.text)")
        let afterFirst = await host.document.source
        #expect(afterFirst.contains("<style id=\"cue-overrides\">") && afterFirst.contains(".headline { color: #2f7bff; }"))
        let second = try await mcp.call("set_deck_style", ["css": ".headline { color: red; } @media (max-width: 1px) { p { color: blue; } }"])
        #expect(!second.isError, "\(second.text)")
        let source = await host.document.source
        #expect(source.contains("color: red;") && !source.contains("#2f7bff"), "same selector replaced")
        #expect(source.contains("background: #111") && source.contains("@media"), "others kept, at-rules added")
        // Each call is one change: undoing the second gives back exactly the first's result…
        _ = try await mcp.call("revert_change", ["id": .string(try #require(MCPHarness.changeID(second.text)))])
        #expect(await host.document.source == afterFirst)
        // …and a lone change undoes to the original bytes.
        let (fresh, freshHost, freshOriginal) = try await connect()
        let only = try await fresh.call("set_deck_style", ["css": "h1 { color: red; }"])
        _ = try await fresh.call("revert_change", ["id": .string(try #require(MCPHarness.changeID(only.text)))])
        #expect(await freshHost.document.source == freshOriginal)
    }

    @Test func deckStyleReplaceAndBadCSS() async throws {
        let (mcp, host, _) = try await connect()
        _ = try await mcp.call("set_deck_style", ["css": "h1 { color: red; }"])
        _ = try await mcp.call("set_deck_style", ["css": "p { margin: 0; }", "mode": "replace"])
        let source = await host.document.source
        #expect(source.contains("p { margin: 0; }") && !source.contains("h1 { color: red; }"))
        for bad in ["h1 { color: red;", "h1 { background: url(javascript:alert(1)) }", "@import url(https://evil.example/x.css);",
                    "h1 {} </style><script>x()</script>"] {
            let reply = try await mcp.call("set_deck_style", ["css": .string(bad)])
            #expect(reply.isError, "accepted: \(bad)")
        }
    }

    @Test func themeVariables() async throws {
        let (mcp, host, _) = try await connect()
        let reply = try await mcp.call("set_theme_variables", ["variables": ["--accent": "#ff5fa2", "--ink": "#101010"]])
        #expect(!reply.isError, "\(reply.text)")
        let source = await host.document.source
        #expect(source.contains(":root") && source.contains("--accent: #ff5fa2") && source.contains("--ink: #101010"))
        let removed = try await mcp.call("set_theme_variables", ["variables": ["--ink": .null]])
        #expect(!removed.isError)
        #expect(await !host.document.source.contains("--ink"))
        #expect(try await mcp.call("set_theme_variables", ["variables": ["color": "red"]]).isError, "only custom properties")
    }

    @Test func addFontAndHeadEdits() async throws {
        let (mcp, host, original) = try await connect()
        let font = try await mcp.call("add_font", ["family": "Playfair Display", "weights": [400, 700]])
        #expect(!font.isError, "\(font.text)")
        #expect(await host.document.source.contains("fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700"))
        #expect(try await mcp.call("add_font", ["family": "x\"><script>"]).isError)

        let head = try await mcp.call("get_head")
        #expect(head.text.contains("fonts.googleapis.com"))
        let edited = try await mcp.call("set_head_html", ["html": .string(head.text + "<title>New</title>")])
        #expect(!edited.isError, "\(edited.text)")
        #expect(await host.document.source.contains("<title>New</title>"))
        _ = try await mcp.call("revert_change", ["id": .string(try #require(MCPHarness.changeID(edited.text)))])
        _ = try await mcp.call("revert_change", ["id": .string(try #require(MCPHarness.changeID(font.text)))])
        #expect(await host.document.source == original)
    }

    @Test func wholeDeckRoundTripKeepsPlaceholdersAndUndoes() async throws {
        let image = "data:image/png;base64," + String(repeating: "QUJD", count: 1_000)
        let css = "/* big */ " + String(repeating: ".a { color: red; } ", count: 1_500)
        let html = Decks.small.replacingOccurrences(of: "</head>", with: "<style>\(css)</style></head>")
            .replacingOccurrences(of: "<p>One</p>", with: "<p>One</p><img src=\"\(image)\">")
        let (mcp, host, original) = try await connect(html)
        let deck = try await mcp.call("get_deck_html")
        #expect(deck.text.contains("CUE-IMAGE-") && deck.text.contains("CUE-BLOCK-"))
        #expect(deck.text.count < 5_000, "big image and stylesheet left out")
        let redesigned = deck.text.replacingOccurrences(of: "Second", with: "Redesigned")
        let reply = try await mcp.call("replace_deck_html", ["html": .string(redesigned)])
        #expect(!reply.isError, "\(reply.text)")
        let source = await host.document.source
        #expect(source.contains("Redesigned") && source.contains(image) && source.contains(css))
        #expect(await host.document.structure.slides.count == 3)
        _ = try await mcp.call("revert_change", ["id": .string(try #require(MCPHarness.changeID(reply.text)))])
        #expect(await host.document.source == original)
        #expect(try await mcp.call("replace_deck_html", ["html": "<html><body><p>No slides</p></body></html>"]).isError)
    }
}
