import Foundation
import JavaScriptCore

/// Parses HTML into an `HTMLNode` tree with exact source offsets, using the
/// bundled parse5 in a bare JavaScriptCore context.
///
/// Security: the context gets only the parse5 bundle. No native functions or
/// objects are exposed to it, and deck scripts are never evaluated here —
/// parse5 treats `<script>` contents as text.
public final class HTMLParser {
    private let context: JSContext

    public init() throws {
        guard let context = JSContext() else { throw HTMLParserError.contextUnavailable }
        guard let url = Bundle.module.url(forResource: "parse5.bundle", withExtension: "js"),
              let bundle = try? String(contentsOf: url, encoding: .utf8)
        else { throw HTMLParserError.bundleMissing }
        context.evaluateScript(bundle)
        if let exception = context.exception { throw HTMLParserError.script(exception.toString() ?? "") }
        self.context = context
    }

    public func parse(_ html: String) throws -> HTMLNode {
        guard let function = context.objectForKeyedSubscript("cueParse") else {
            throw HTMLParserError.bundleMissing
        }
        let result = function.call(withArguments: [html])
        if let exception = context.exception {
            context.exception = nil
            throw HTMLParserError.script(exception.toString() ?? "")
        }
        guard let json = result?.toString(), let data = json.data(using: .utf8) else {
            throw HTMLParserError.badOutput
        }
        return try JSONDecoder().decode(RawNode.self, from: data).node
    }
}

public enum HTMLParserError: Error, Equatable {
    case contextUnavailable
    case bundleMissing
    case script(String)
    case badOutput
}
