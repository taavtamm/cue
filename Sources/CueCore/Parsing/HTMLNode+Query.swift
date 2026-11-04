import Foundation

/// Small, readable tree queries for adapters. Not a CSS engine.
extension HTMLNode {
    /// Every descendant (not self) in document order.
    public var descendants: [HTMLNode] {
        var result: [HTMLNode] = []
        func walk(_ node: HTMLNode) {
            for child in node.children {
                result.append(child)
                walk(child)
            }
        }
        walk(self)
        return result
    }

    /// Descendants matching a predicate, in document order, with their paths
    /// (child-element indices from this node).
    public func findAll(_ match: (HTMLNode) -> Bool) -> [(node: HTMLNode, path: ElementPath)] {
        var result: [(HTMLNode, ElementPath)] = []
        func walk(_ node: HTMLNode, _ path: ElementPath) {
            for (index, child) in node.children.enumerated() {
                let childPath = path + [index]
                if match(child) { result.append((child, childPath)) }
                walk(child, childPath)
            }
        }
        walk(self, [])
        return result
    }

    public func first(where match: (HTMLNode) -> Bool) -> HTMLNode? {
        for child in children {
            if match(child) { return child }
            if let found = child.first(where: match) { return found }
        }
        return nil
    }

    public var head: HTMLNode? { children.first { $0.tag == "head" } }
    public var body: HTMLNode? { children.first { $0.tag == "body" } }

    /// `<meta name="…" content="…">` in the head.
    public func meta(named name: String) -> String? {
        head?.children.first { $0.tag == "meta" && $0["name"] == name }?["content"]
    }

    public func hasClass(_ name: String) -> Bool { classes.contains(name) }
}
