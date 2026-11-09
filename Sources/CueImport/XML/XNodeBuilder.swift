import Foundation

/// Small helpers for building nodes in code.
enum XNodeBuilder {
    /// A parent named `name` holding `node`, renamed to `as`, so readers that
    /// expect `spPr/ln` also work for a table cell's `lnL`.
    static func wrap(_ node: XNode, as childName: String) -> XNode {
        let renamed = XNode(name: childName, attributes: node.attributes)
        renamed.children = node.children
        renamed.contents = node.contents
        renamed.text = node.text
        let parent = XNode(name: "wrapper", attributes: [:])
        parent.appendChild(renamed)
        return parent
    }
}
