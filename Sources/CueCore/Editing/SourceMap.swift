import Foundation

/// Every element of the deck in document order, with its exact source
/// ranges. Built from the parse5 tree after each edit.
///
/// Identity: `cueID` (document-order index) is what the live page carries;
/// `path` is what survives an edit that doesn't add or remove elements.
public struct SourceMap: Sendable {
    public let elements: [MappedElement]
    private let byPath: [ElementPath: Int]

    public init(root: HTMLNode, source: String) {
        let text = SourceText(source)
        var elements: [MappedElement] = []
        func walk(_ node: HTMLNode, _ path: ElementPath) {
            let locations = node.attributeRanges.mapValues { AttributeLocation(range: $0, in: text) }
            elements.append(MappedElement(
                cueID: String(elements.count), tag: node.tag, path: path, attributes: node.attributes,
                range: node.range, startTag: node.startTagRange, endTag: node.endTagRange,
                attributeLocations: locations, childCount: node.children.count
            ))
            for (index, child) in node.children.enumerated() { walk(child, path + [index]) }
        }
        walk(root, [])
        self.elements = elements
        byPath = Dictionary(uniqueKeysWithValues: elements.enumerated().map { ($1.path, $0) })
    }

    public func element(at path: ElementPath) -> MappedElement? {
        byPath[path].map { elements[$0] }
    }

    public func element(cueID: String) -> MappedElement? {
        Int(cueID).flatMap { elements.indices.contains($0) ? elements[$0] : nil }
    }

    /// The same element after a re-parse: same path and tag, else nil.
    public func counterpart(of element: MappedElement) -> MappedElement? {
        guard let match = self.element(at: element.path), match.tag == element.tag else { return nil }
        return match
    }

    /// The innermost element whose source contains `offset`.
    public func element(containing offset: Int) -> MappedElement? {
        elements.last { element in
            guard let range = element.range else { return false }
            return range.start <= offset && offset < range.end
        }
    }

    /// What CueBridge needs to tag the live DOM: `[cueID, tag]` in document
    /// order, minus elements the served page doesn't contain.
    public func liveManifest(excluding removed: SourceRange?) -> [LiveElement] {
        elements.compactMap { element in
            if let removed, let range = element.range, removed.start <= range.start, range.end <= removed.end {
                return nil
            }
            return LiveElement(cueID: element.cueID, tag: element.tag)
        }
    }
}

/// One entry of the live mapping manifest sent to CueBridge.
public struct LiveElement: Sendable, Equatable, Codable {
    public let cueID: String
    public let tag: String
}
