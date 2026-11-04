import CueCore

extension HTMLNode {
    /// The element at a child-index path from this node (`[]` is this node).
    func node(at path: ElementPath) -> HTMLNode? {
        var node: HTMLNode? = self
        for index in path {
            guard let current = node, current.children.indices.contains(index) else { return nil }
            node = current.children[index]
        }
        return node
    }
}
