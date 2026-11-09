import CueCore
import Foundation
import MCP

/// Serving an Ask-bar request through MCP sampling, when the connected
/// client offers it: Cue asks the client's model for a JSON plan of tool
/// calls and runs them itself, as one request.
///
/// The SDK's `requestSampling` (0.12.1) carries no tool definitions, so the
/// tools are described in the prompt and the model answers in one structured
/// reply. Without sampling, requests wait for `next_request` instead.
public enum AskSampler {
    /// Tools the model may use in its plan: the ones that change the deck.
    static let planTools = ToolCatalog.slides + ToolCatalog.elements + ToolCatalog.inserting

    /// Runs the request and returns the summary to show the user.
    public static func serve(_ request: RequestMailbox.Request, server: Server, host: DeckHost,
                             client: String) async throws -> String {
        // The deck goes to this client and its plan runs: only if the user allowed it.
        if let refusal = await CueMCPServer.refusal(for: client, host: host) { throw CueMCPError.invalid(refusal) }
        guard let document = await host.currentDocument() else { throw CueMCPError.noDeck }
        let prompt = try await self.prompt(for: request, document: document, host: host)
        let result = try await server.requestSampling(
            messages: [.user(.single(.text(prompt)))], systemPrompt: systemPrompt, maxTokens: 4000
        )
        let reply = text(of: result.content)
        let plan = try parse(reply)
        let runner = ToolRunner(host: host, client: client)
        var failures: [String] = []
        for call in plan.calls {
            let outcome = await runner.run(call.tool, call.arguments)
            if outcome.isError == true, case .text(let message, _, _)? = outcome.content.first { failures.append(message) }
        }
        return failures.isEmpty ? plan.summary : plan.summary + " (Some steps failed: " + failures.joined(separator: "; ") + ")"
    }

    static let systemPrompt = """
        You edit an HTML slide deck open in Cue. Reply with JSON only, no prose: \
        {"summary": "<one line for the user>", "calls": [{"tool": "<tool>", "arguments": {...}}]}. \
        Slide numbers are 1-based. Prefer small edit_element changes. Tools you may call:
        """ + planTools.map { "\n- \($0.name): \($0.description ?? "")" }.joined()

    static func prompt(for request: RequestMailbox.Request, document: DeckDocument, host: DeckHost) async throws -> String {
        let outline = try ResourceCatalog.encode(DeckOutline(document))
        let selection = try await host.selection().map(ResourceCatalog.encode) ?? "nothing selected"
        let index = min(max(0, request.slide - 1), max(0, document.structure.slides.count - 1))
        let html = document.structure.slides.indices.contains(index)
            ? document.structure.slides[index].sourceRange.map { DeckOutline.slice(document.source, $0, limit: 60_000) } ?? ""
            : ""
        return """
            Request: \(request.text)
            The user is on slide \(request.slide). Selection: \(selection)
            Outline: \(outline)
            Slide \(request.slide) HTML:
            \(html)
            """
    }

    struct Plan {
        struct Call { let tool: String; let arguments: [String: Value] }
        let summary: String
        let calls: [Call]
    }

    /// The JSON object in the reply (models sometimes wrap it in a code fence).
    static func parse(_ reply: String) throws -> Plan {
        guard let start = reply.firstIndex(of: "{"), let end = reply.lastIndex(of: "}"),
              let object = try? JSONDecoder().decode([String: Value].self, from: Data(reply[start...end].utf8))
        else { throw CueMCPError.invalid("The model's reply wasn't the JSON plan Cue asked for.") }
        let allowed = Set(planTools.map(\.name))
        let calls = (object["calls"]?.arrayValue ?? []).compactMap { value -> Plan.Call? in
            guard let call = value.objectValue, let tool = call["tool"]?.stringValue, allowed.contains(tool) else { return nil }
            return Plan.Call(tool: tool, arguments: call["arguments"]?.objectValue ?? [:])
        }
        return Plan(summary: object["summary"]?.stringValue ?? "Done", calls: calls)
    }

    static func text(of content: Sampling.Message.Content) -> String {
        let blocks: [Sampling.Message.Content.ContentBlock]
        switch content {
        case .single(let block): blocks = [block]
        case .multiple(let list): blocks = list
        }
        return blocks.compactMap { if case .text(let text) = $0 { text } else { nil } }.joined(separator: "\n")
    }
}
