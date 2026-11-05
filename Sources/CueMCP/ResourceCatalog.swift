import CueCore
import Foundation
import MCP

/// Cue's MCP resources: the outline, one slide's HTML, the selection and
/// the deck's assets. The same data as the read tools, for clients that
/// prefer resources.
enum ResourceCatalog {
    static let outline = "cue://deck/outline"
    static let selection = "cue://editor/selection"
    static let assets = "cue://deck/assets"
    static let slideTemplate = "cue://deck/slide/{n}/html"

    static let resources: [Resource] = [
        Resource(name: "Deck outline", uri: outline, description: "Slides, labels, notes and build counts.",
                 mimeType: "application/json"),
        Resource(name: "Selection", uri: selection, description: "What the user has selected in Cue right now.",
                 mimeType: "application/json"),
        Resource(name: "Assets", uri: assets, description: "Images the deck uses: embedded and files.",
                 mimeType: "application/json"),
    ]

    static let templates: [Resource.Template] = [
        Resource.Template(uriTemplate: slideTemplate, name: "Slide HTML",
                          description: "One slide's HTML as written in the file; n is 1-based.", mimeType: "text/html"),
    ]

    static func read(_ uri: String, runner: ToolRunner) async throws -> ReadResource.Result {
        let content: String
        switch uri {
        case outline: content = try encode(DeckOutline(try await runner.document()))
        case selection: content = try await runner.host.selection().map(encode) ?? "null"
        case assets: content = try encode(DeckAssets(try await runner.document()))
        default:
            guard let number = slideNumber(in: uri) else { throw CueMCPError.invalid("Cue has no resource \(uri).") }
            let document = try await runner.document()
            guard document.structure.slides.indices.contains(number - 1),
                  let range = document.structure.slides[number - 1].sourceRange else {
                throw CueMCPError.invalid("Slide \(number) doesn't exist.")
            }
            return ReadResource.Result(contents: [.text(DeckOutline.slice(document.source, range, limit: 200_000),
                                                        uri: uri, mimeType: "text/html")])
        }
        return ReadResource.Result(contents: [.text(content, uri: uri, mimeType: "application/json")])
    }

    /// `cue://deck/slide/3/html` → 3.
    static func slideNumber(in uri: String) -> Int? {
        let prefix = "cue://deck/slide/", suffix = "/html"
        guard uri.hasPrefix(prefix), uri.hasSuffix(suffix) else { return nil }
        return Int(uri.dropFirst(prefix.count).dropLast(suffix.count))
    }

    static func encode(_ value: some Encodable) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}

/// Images the deck uses: embedded `data:` images (by type and size) and
/// files it refers to by path.
struct DeckAssets: Encodable {
    struct Embedded: Encodable { let type: String; let kilobytes: Int }
    let embedded: [Embedded]
    let files: [String]

    init(_ document: DeckDocument) {
        let nodes = document.tree.findAll { ["img", "source", "image", "video"].contains($0.tag) }.map(\.node)
        let sources = nodes.compactMap { $0["src"] ?? $0["href"] ?? $0["poster"] }
        embedded = sources.filter { $0.hasPrefix("data:") }.map { uri in
            let type = String(uri.dropFirst(5).prefix { $0 != ";" && $0 != "," })
            return Embedded(type: type, kilobytes: uri.utf8.count * 3 / 4 / 1024)
        }
        files = Array(Set(sources.filter { !$0.hasPrefix("data:") })).sorted()
    }
}
