import CoreGraphics
import CueCore
import Foundation
import ImageIO
import MCP
import Testing
import UniformTypeIdentifiers
@testable import CueMCP

/// Embeds, transitions, images from the web, contact sheets and activity.
@Suite("Design tools on real decks", .serialized)
struct DesignDeckToolTests {
    static var demo-deck: String {
        get throws { try String(contentsOf: Decks.repoRoot.appending(path: "fixtures/demo-deck.html"), encoding: .utf8) }
    }

    @Test func embedsReadAndEditOnlyTheirOwnJSON() async throws {
        let (document, _) = try Decks.document(try Self.demo-deck)
        let host = FakeHost(document)
        let mcp = try await MCPHarness.connect(host)
        let listed = try await mcp.call("get_embeds", ["slide": 2])
        #expect(!listed.isError && listed.text.contains("e0-1gp23mk"), "\(listed.text.prefix(300))")
        let reply = try await mcp.call("edit_embed", ["slide": 2, "embed": "e0-1gp23mk",
                                                      "html": "<!doctype html><p>Replaced embed</p>"])
        #expect(!reply.isError, "\(reply.text)")
        let edited = await host.document
        #expect(edited.embeds(onSlide: 1).first?.html == "<!doctype html><p>Replaced embed</p>")
        #expect(edited.embeds(onSlide: 2) == document.embeds(onSlide: 2), "other slides untouched")
        let patch = SourceEdit.difference(from: document.source, to: edited.source)
        let script = try #require(document.sourceMap.elements.first { $0.attributes["id"] == "deck-motion" }?.innerRange)
        #expect(patch.patches.allSatisfy { $0.range.start >= script.start && $0.range.end <= script.end }, "inside deck-motion only")
        _ = try await mcp.call("revert_change", ["id": .string(try #require(MCPHarness.changeID(reply.text)))])
        #expect(await host.document.source == document.source)
        #expect(try await mcp.call("edit_embed", ["slide": 2, "embed": "nope", "html": "x"]).isError)
    }

    @Test func transitionsForBothKindsOfDeck() async throws {
        let (claudeDeck, _) = try Decks.document(try Self.demo-deck)
        let design = try await MCPHarness.connect(FakeHost(claudeDeck))
        #expect(!(try await design.call("set_transition", ["slide": 1, "kind": "push"])).isError)
        #expect(await design.host.document.transition(ofSlide: 0) == "push")
        #expect(!(try await design.call("set_transition", ["slide": 1, "kind": "none"])).isError)
        #expect(await design.host.document.transition(ofSlide: 0) == nil)

        let (cueDeck, _) = try Decks.document()
        let cue = try await MCPHarness.connect(FakeHost(cueDeck))
        #expect(!(try await cue.call("set_transition", ["slide": 2, "kind": "fade"])).isError)
        #expect(await cue.host.document.source.contains("<section data-cue-slide id=\"middle\" data-cue-transition=\"fade\">"))
        #expect(try await cue.call("set_transition", ["slide": 2, "kind": "spin"]).isError)
    }

    @Test func imagesFromTheWebAreDownloadedScaledAndNamed() async throws {
        StubImageServer.responses["https://images.example/photo.png"] = (200, "image/png", try Self.png(width: 6000, height: 3000))
        StubImageServer.responses["https://images.example/page"] = (200, "text/html", Data("<html></html>".utf8))
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        await host.setDownloader(ImageDownloader(session: StubImageServer.session()))
        let mcp = try await MCPHarness.connect(host)
        let reply = try await mcp.call("insert_image", ["slide": 1, "url": "https://images.example/photo.png", "description": "A photo"])
        #expect(!reply.isError, "\(reply.text)")
        #expect(reply.text.contains("images.example"), "the change names where the image came from")
        let source = await host.document.source
        let start = try #require(source.range(of: "data:image/"))
        let uri = String(source[start.lowerBound...].prefix { $0 != "\"" })
        let data = try #require(Data(base64Encoded: String(uri.split(separator: ",")[1])))
        let image = try #require(CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        #expect(image.width <= 3840 && image.height <= 2160, "scaled to at most 2× the canvas")
        #expect(try await mcp.call("insert_image", ["slide": 1, "url": "https://images.example/page", "description": "x"]).isError)
        #expect(try await mcp.call("insert_image", ["slide": 1, "url": "http://images.example/photo.png", "description": "x"]).isError)
    }

    @Test func contactSheetIsAPNG() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let (content, isError) = try await mcp.client.callTool(name: "render_deck", arguments: ["columns": 2])
        #expect(isError != true)
        guard case .image(let base64, let type, _, _) = try #require(content.first) else { Issue.record("no image"); return }
        #expect(type == "image/png" && Data(base64Encoded: base64)?.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
        #expect(try await mcp.call("render_deck", ["slides": [9]]).isError)
    }

    @Test func stylesSummaryOfARealDeckStaysSmall() async throws {
        let (document, _) = try Decks.document(try Self.demo-deck)
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let summary = try await mcp.call("get_styles")
        #expect(!summary.isError && summary.text.count < 40_000, "\(summary.text.count) characters")
        #expect(summary.text.contains("font_families") && summary.text.contains("Inter"))
        let rules = try await mcp.call("get_styles", ["selector": ".deck-slide"])
        #expect(rules.text.contains(".deck-slide") && rules.text.count < 40_000)
    }

    @Test func activityIsReportedAroundEveryApprovedCall() async throws {
        #expect(ToolActivity.kind(forTool: "get_outline") == .reading)
        #expect(ToolActivity.kind(forTool: "render_deck") == .rendering)
        #expect(ToolActivity.kind(forTool: "next_request") == .waiting)
        #expect(ToolActivity.kind(forTool: "complete_request") == .reading)
        #expect(ToolActivity.kind(forTool: "set_deck_style") == .editing)
        for tool in ToolCatalog.tools.map(\.name) where !tool.hasPrefix("get_") && tool != "list_changes" {
            _ = ToolActivity.kind(forTool: tool) // Every tool maps (no crash, no default surprise).
        }
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        let mcp = try await MCPHarness.connect(host)
        _ = try await mcp.call("get_outline")
        _ = try await mcp.call("edit_element", ["target": ["slide": 9, "selector": "h1"], "text": "x"])
        _ = try await mcp.call("next_request", ["timeout_seconds": 1])
        #expect(await host.activityLog == ["start get_outline", "finish get_outline", "start edit_element",
                                           "finish edit_element failed", "start next_request", "finish next_request"])
        #expect(await host.activities.map(\.slide) == [nil, 9, nil])
        await host.setDecision(.denied)
        _ = try await mcp.call("get_outline")
        #expect(await host.activityLog.count == 6, "refused calls aren't reported")
    }

    static func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
