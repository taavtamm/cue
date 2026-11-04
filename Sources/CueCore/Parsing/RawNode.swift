import Foundation

/// The compact JSON shape produced by `Web/src/parse.js`.
/// Keys: t tag, a attrs, ar attr ranges, r range, s start tag, x text, c children.
struct RawNode: Decodable {
    let t: String
    let a: [String: String]
    let ar: [String: [Int]]
    let r: [Int]?
    let s: [Int]?
    let x: String
    let c: [RawNode]

    var node: HTMLNode {
        HTMLNode(
            tag: t,
            attributes: a,
            attributeRanges: ar.compactMapValues(Self.range),
            range: r.flatMap(Self.range),
            startTagRange: s.flatMap(Self.range),
            text: x,
            children: c.map(\.node)
        )
    }

    private static func range(_ pair: [Int]) -> SourceRange? {
        pair.count == 2 ? SourceRange(start: pair[0], end: pair[1]) : nil
    }
}
