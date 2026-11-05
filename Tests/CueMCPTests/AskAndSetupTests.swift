import CueCore
import Foundation
import MCP
import Testing
@testable import CueMCP

@Suite("Ask bar, approvals and setup")
struct AskAndSetupTests {
    @Test func nextRequestWaitsForTheAskBar() async throws {
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        let mcp = try await MCPHarness.connect(host)
        let posted = Task {
            try await Task.sleep(for: .milliseconds(200))
            return await host.mailbox.post("Make slide 3's headline shorter", slide: 3, selection: nil)
        }
        let started = Date()
        let reply = try await mcp.call("next_request", ["timeout_seconds": 10])
        let request = try await posted.value
        #expect(reply.text.contains("Make slide 3's headline shorter") && reply.text.contains(request.id))
        #expect(Date().timeIntervalSince(started) < 5, "returned when the request arrived, not at the timeout")
        #expect(await host.mailbox.request(request.id)?.status == .working)

        _ = try await mcp.call("complete_request", ["id": .string(request.id), "summary": "Shortened it"])
        #expect(await host.mailbox.request(request.id)?.status == .done)
        #expect(await host.mailbox.request(request.id)?.summary == "Shortened it")
    }

    @Test func nextRequestTimesOutWithNull() async throws {
        let (document, _) = try Decks.document()
        let mcp = try await MCPHarness.connect(FakeHost(document))
        let reply = try await mcp.call("next_request", ["timeout_seconds": 1])
        #expect(reply.text.hasPrefix("null"))
    }

    @Test func approvalsAreRememberedByClient() throws {
        let defaults = try #require(UserDefaults(suiteName: "cue-approvals-\(UUID().uuidString)"))
        let approvals = ClientApproval(defaults: defaults)
        #expect(approvals.decision(for: "claude-code") == .pending)
        approvals.set(.approved, for: "claude-code")
        approvals.set(.denied, for: "other")
        #expect(ClientApproval(defaults: defaults).decision(for: "claude-code") == .approved)
        #expect(approvals.decision(for: "other") == .denied)
        approvals.set(.pending, for: "claude-code") // Revoke.
        #expect(approvals.decision(for: "claude-code") == .pending)
        #expect(approvals.remembered.map(\.client) == ["other"])
    }

    @Test func claudeDesktopConfigKeepsOtherServers() throws {
        let existing = Data(#"{"mcpServers":{"github":{"command":"gh-mcp"}},"theme":"dark"}"#.utf8)
        let merged = try ClaudeSetup.merged(existing, helperPath: "/Applications/Cue.app/Contents/MacOS/cue-mcp")
        let object = try #require(try JSONSerialization.jsonObject(with: merged) as? [String: Any])
        let servers = try #require(object["mcpServers"] as? [String: Any])
        #expect(servers["github"] != nil && object["theme"] as? String == "dark")
        #expect((servers["cue"] as? [String: Any])?["command"] as? String == "/Applications/Cue.app/Contents/MacOS/cue-mcp")
        #expect(throws: ClaudeSetup.SetupError.self) { try ClaudeSetup.merged(Data("not json".utf8), helperPath: "x") }
    }

    @Test func addingToClaudeDesktopBacksUpFirst() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-desktop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let config = folder.appending(path: "claude_desktop_config.json")
        try Data(#"{"mcpServers":{"other":{"command":"x"}}}"#.utf8).write(to: config)
        let backup = try #require(try ClaudeSetup.addToClaudeDesktop(helperPath: "/x/cue-mcp", config: config))
        #expect(try String(contentsOf: backup, encoding: .utf8).contains("other"))
        let text = try String(contentsOf: config, encoding: .utf8)
        #expect(text.contains("other") && text.contains("/x/cue-mcp"))
        #expect(ClaudeSetup.claudeCodeCommand(helperPath: "/x/cue-mcp") == "claude mcp add cue -- \"/x/cue-mcp\"")
    }

    @Test func samplingPlansAreParsedAndLimitedToEditTools() throws {
        let reply = """
            ```json
            {"summary": "Shorter headline", "calls": [
              {"tool": "edit_element", "arguments": {"target": {"slide": 3, "selector": "h1"}, "text": "Q3 won"}},
              {"tool": "delete_slide", "arguments": {"slide": 1}},
              {"tool": "next_request", "arguments": {}}
            ]}
            ```
            """
        let plan = try AskSampler.parse(reply)
        #expect(plan.summary == "Shorter headline")
        #expect(plan.calls.map(\.tool) == ["edit_element", "delete_slide"], "only tools that edit the deck")
        #expect(throws: CueMCPError.self) { try AskSampler.parse("I can't do that") }
    }
}
