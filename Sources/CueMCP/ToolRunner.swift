import CueCore
import Foundation
import MCP

/// Runs one tool call against the host. Problems come back as tool errors
/// with a plain message, so Claude can correct itself and try again.
struct ToolRunner: Sendable {
    let host: DeckHost
    let client: String

    func run(_ name: String, _ arguments: [String: Value]?) async -> CallTool.Result {
        do {
            return try await dispatch(name, ToolArguments(arguments))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return CallTool.Result(content: [.text(message)], isError: true)
        }
    }

    private func dispatch(_ name: String, _ args: ToolArguments) async throws -> CallTool.Result {
        switch name {
        case "get_outline": return try json(DeckOutline(try await document()))
        case "get_slide_html": return try await slideHTML(args)
        case "get_selection": return try await selection()
        case "render_slide": return try await render(args)
        case "list_changes": return try json(await host.changes().map(ChangeSetReport.init))
        case "accept_change":
            try await host.accept(try args.requiredString("id"))
            return text("Accepted \(try args.requiredString("id")).")
        case "revert_change":
            try await host.revert(try args.requiredString("id"))
            return text("Undid \(try args.requiredString("id")).")
        case "next_request": return try await nextRequest(args)
        case "complete_request":
            try await host.mailbox.complete(try args.requiredString("id"), summary: args.string("summary"))
            return text("Marked \(try args.requiredString("id")) done.")
        default:
            if let result = try await deck(name, args) { return result }
            if let result = try await design(name, args) { return result }
            return try await edit(name, args)
        }
    }

    // MARK: Reading

    func document() async throws -> DeckDocument {
        guard let document = await host.currentDocument() else { throw CueMCPError.noDeck }
        return document
    }

    private func slideHTML(_ args: ToolArguments) async throws -> CallTool.Result {
        let document = try await document()
        let index = try args.slideIndex(in: DeckDocumentFacts(slideCount: document.structure.slides.count))
        guard let range = document.structure.slides[index].sourceRange else {
            throw CueMCPError.invalid("Slide \(index + 1) has no source range.")
        }
        return text(DeckOutline.slice(document.source, range, limit: 200_000))
    }

    private func selection() async throws -> CallTool.Result {
        guard let selection = await host.selection() else {
            return text("Nothing is selected in Cue. The user is on the slide shown by get_outline's “current”, if any.")
        }
        return try json(selection)
    }

    private func render(_ args: ToolArguments) async throws -> CallTool.Result {
        let document = try await document()
        let index = try args.slideIndex(in: DeckDocumentFacts(slideCount: document.structure.slides.count))
        let png = try await host.renderSlide(index, build: args.int("build"))
        return CallTool.Result(content: [.image(data: png.base64EncodedString(), mimeType: "image/png", metadata: nil)])
    }

    private func nextRequest(_ args: ToolArguments) async throws -> CallTool.Result {
        let seconds = min(300, max(1, args.int("timeout_seconds") ?? 50))
        guard let request = await host.mailbox.next(timeout: .seconds(seconds)) else {
            return text("null — no request in \(seconds) s. Call next_request again to keep listening.")
        }
        return try json(request)
    }

    // MARK: Output

    func text(_ value: String) -> CallTool.Result { CallTool.Result(content: [.text(value)]) }

    func json(_ value: some Encodable) throws -> CallTool.Result {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return text(String(decoding: try encoder.encode(value), as: UTF8.self))
    }
}
