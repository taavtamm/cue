import CueCore

/// The selected element's place in the slide, e.g.
/// `section.deck-slide#3 › div.deck-scaler › h1.headline`.
public enum Breadcrumb {
    /// From the slide element down to `path`. Elements outside any slide
    /// start from `<body>`. Wrappers with nothing to tell them apart are kept,
    /// because they help the user see how deep the selection is.
    public static func items(for path: ElementPath, slidePath: ElementPath?, in map: SourceMap) -> [String] {
        let start: Int
        if let slidePath, path.starts(with: slidePath) {
            start = slidePath.count
        } else {
            start = min(1, path.count) // [1] is <body> under <html>.
        }
        return (start...path.count).compactMap { length in
            map.element(at: Array(path.prefix(length))).map(describe)
        }
    }

    /// `tag.firstClass#id`, the way the design and the web inspector write it.
    public static func describe(_ element: MappedElement) -> String {
        var text = element.tag
        let firstClass = (element.attributes["class"] ?? "").split(whereSeparator: \.isWhitespace).first
        if let firstClass { text += ".\(firstClass)" }
        if let id = element.attributes["id"], !id.isEmpty { text += "#\(id)" }
        return text
    }

    public static func joined(_ items: [String]) -> String { items.joined(separator: " › ") }
}
