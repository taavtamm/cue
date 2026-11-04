import Foundation

/// Finds the layout and master placeholders a slide placeholder inherits
/// its position, text styles and body settings from.
struct PptxPlaceholders {
    let layoutTree: XNode?
    let masterTree: XNode?
    /// The master's `p:txStyles` (titleStyle, bodyStyle, otherStyle).
    let masterTextStyles: XNode?

    struct Inherited {
        var layout: XNode?
        var master: XNode?
        var shapes: [XNode] { [master, layout].compactMap { $0 } }
    }

    static func placeholder(of shape: XNode) -> XNode? {
        for wrapper in ["nvSpPr", "nvPicPr", "nvGraphicFramePr", "nvCxnSpPr"] {
            if let ph = shape.child(wrapper)?.child("nvPr")?.child("ph") { return ph }
        }
        return nil
    }

    func inherited(for ph: XNode) -> Inherited {
        let layout = match(ph, in: layoutTree, byIndex: true)
        let typeSource = layout.flatMap(Self.placeholder(of:)) ?? ph
        let master = match(typeSource, in: masterTree, byIndex: false) ?? match(ph, in: masterTree, byIndex: false)
        return Inherited(layout: layout, master: master)
    }

    /// The master list style a placeholder of this type starts from.
    func baseListStyle(for ph: XNode?) -> XNode? {
        guard let ph else { return nil }
        switch Self.family(ph["type"]) {
        case "title": return masterTextStyles?.child("titleStyle")
        case "body": return masterTextStyles?.child("bodyStyle")
        default: return masterTextStyles?.child("otherStyle")
        }
    }

    /// Layouts match by index first, then type; masters match by type family.
    private func match(_ ph: XNode, in tree: XNode?, byIndex: Bool) -> XNode? {
        guard let tree else { return nil }
        let candidates = tree.descendants.filter { Self.placeholder(of: $0) != nil }
        if byIndex, let index = ph["idx"], let found = candidates.first(where: { Self.placeholder(of: $0)?["idx"] == index }) {
            return found
        }
        let type = ph["type"] ?? "body"
        if let exact = candidates.first(where: { (Self.placeholder(of: $0)?["type"] ?? "body") == type }) { return exact }
        let family = Self.family(type)
        return candidates.first { Self.family(Self.placeholder(of: $0)?["type"]) == family }
    }

    static func family(_ type: String?) -> String {
        switch type ?? "body" {
        case "title", "ctrTitle": "title"
        case "body", "subTitle", "obj", "tbl", "chart", "media", "clipArt", "dgm", "pic": "body"
        default: type ?? "body"
        }
    }
}
