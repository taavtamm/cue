import Foundation

/// Reuses `HTMLParser`s across edits. Making one creates a JSContext and
/// evaluates the parse5 bundle, which costs more than parsing a typical deck,
/// and every edit re-parses. A JSContext must only be used by one thread at a
/// time, so each parser is lent to one caller and handed back after; callers
/// on other threads at the same moment get their own.
final class HTMLParserPool: @unchecked Sendable {
    static let shared = HTMLParserPool()

    /// Idle parsers kept beyond this are dropped.
    private let capacity = 4
    private let lock = NSLock()
    private var idle: [HTMLParser] = []

    func parse(_ html: String) throws -> HTMLNode {
        let parser = try lock.withLock { idle.popLast() } ?? HTMLParser()
        defer { lock.withLock { if idle.count < capacity { idle.append(parser) } } }
        return try parser.parse(html)
    }
}
