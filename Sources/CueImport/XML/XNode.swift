import Foundation

/// A parsed XML element. Element names are local names (`a:off` → `off`).
/// Attributes are kept by local name (`r:embed` → `embed`) and, for prefixed
/// ones, by their full name too (`r:id`), since some elements carry both.
public final class XNode: @unchecked Sendable {
    public let name: String
    public let attributes: [String: String]
    public internal(set) var children: [XNode] = []
    /// Character data directly inside this element.
    public internal(set) var text = ""
    /// Character data and child elements interleaved, in document order.
    public internal(set) var contents: [XContent] = []

    /// Adds character data to `text` and to `contents`, merging adjacent runs
    /// (XMLParser may report one run in several pieces).
    func appendText(_ string: String) {
        text += string
        if case .text(let previous) = contents.last {
            contents[contents.count - 1] = .text(previous + string)
        } else {
            contents.append(.text(string))
        }
    }

    func appendChild(_ node: XNode) {
        children.append(node)
        contents.append(.element(node))
    }

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    public subscript(_ attribute: String) -> String? { attributes[attribute] }

    public func child(_ name: String) -> XNode? { children.first { $0.name == name } }

    public func children(_ name: String) -> [XNode] { children.filter { $0.name == name } }

    /// Follows a path of child names: `node.at("spPr", "xfrm", "off")`.
    public func at(_ path: String...) -> XNode? {
        var node: XNode? = self
        for name in path { node = node?.child(name) }
        return node
    }

    /// Every descendant, depth first, in document order.
    public var descendants: [XNode] {
        children.flatMap { [$0] + $0.descendants }
    }

    public func first(_ name: String) -> XNode? {
        for child in children {
            if child.name == name { return child }
            if let found = child.first(name) { return found }
        }
        return nil
    }

    public func double(_ attribute: String) -> Double? { attributes[attribute].flatMap(Double.init) }
    public func int(_ attribute: String) -> Int? { attributes[attribute].flatMap(Int.init) }

    /// XML booleans: "1"/"true" are true.
    public func bool(_ attribute: String) -> Bool? {
        attributes[attribute].map { $0 == "1" || $0 == "true" }
    }
}
