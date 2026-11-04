import Foundation

public enum XMLTreeError: Error, LocalizedError {
    case malformed(String, line: Int)
    public var errorDescription: String? {
        switch self {
        case .malformed(let part, let line): "“\(part)” isn't valid XML (line \(line))."
        }
    }
}

/// Builds an `XNode` tree with Foundation's streaming XMLParser.
public enum XMLTreeParser {
    public static func parse(_ data: Data, name: String = "XML") throws -> XNode {
        let builder = Builder()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = builder
        guard parser.parse(), let root = builder.root else {
            throw XMLTreeError.malformed(name, line: parser.lineNumber)
        }
        return root
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var root: XNode?
        private var stack: [XNode] = []

        func parser(
            _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String] = [:]
        ) {
            // Unprefixed names win; prefixed ones are also kept whole, so a
            // `p:sldId` with both `id` and `r:id` keeps both.
            var local: [String: String] = [:]
            for (key, value) in attributes where !key.contains(":") { local[key] = value }
            for (key, value) in attributes where key.contains(":") {
                local[key] = value
                let name = Self.localName(key)
                if local[name] == nil { local[name] = value }
            }
            let node = XNode(name: Self.localName(elementName), attributes: local)
            stack.last?.children.append(node)
            if stack.isEmpty { root = node }
            stack.append(node)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            stack.removeLast()
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            stack.last?.text += string
        }

        static func localName(_ name: String) -> String {
            name.firstIndex(of: ":").map { String(name[name.index(after: $0)...]) } ?? name
        }
    }
}
