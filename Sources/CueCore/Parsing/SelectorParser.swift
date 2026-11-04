import Foundation

/// Tokenises one comma-free selector into a right-to-left chain.
enum SelectorParser {
    static func chain(_ text: String) -> SimpleSelector.Chain? {
        // Normalise `a>b` and `a > b` to tokens separated by spaces.
        let spaced = text.replacingOccurrences(of: ">", with: " > ")
        let tokens = spaced.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return nil }

        var leftToRight: [(SimpleSelector.Compound, SimpleSelector.Combinator)] = []
        var pending: SimpleSelector.Combinator = .descendant
        for token in tokens {
            if token == ">" {
                guard !leftToRight.isEmpty else { return nil }
                pending = .child
                continue
            }
            guard let compound = compound(token) else { return nil }
            leftToRight.append((compound, pending))
            pending = .descendant
        }
        // Each entry's combinator describes its link to the entry on its left.
        var chain: SimpleSelector.Chain = []
        for (index, entry) in leftToRight.enumerated().reversed() {
            let link = index > 0 ? entry.1 : .descendant
            chain.append((entry.0, link))
        }
        return chain
    }

    static func compound(_ token: String) -> SimpleSelector.Compound? {
        var compound = SimpleSelector.Compound()
        var scanner = Substring(token)
        if let tag = takeName(&scanner) { compound.tag = tag.lowercased() }
        while let marker = scanner.first {
            scanner.removeFirst()
            switch marker {
            case ".":
                guard let name = takeName(&scanner) else { return nil }
                compound.classes.append(name)
            case "#":
                guard let name = takeName(&scanner) else { return nil }
                compound.id = name
            case "[":
                guard let close = scanner.firstIndex(of: "]") else { return nil }
                let body = scanner[..<close]
                scanner = scanner[scanner.index(after: close)...]
                compound.attributes.append(attribute(body))
            default:
                return nil
            }
        }
        return compound
    }

    private static func attribute(_ body: Substring) -> (name: String, value: String?) {
        let parts = body.split(separator: "=", maxSplits: 1)
        let name = parts[0].trimmingCharacters(in: .whitespaces)
        guard parts.count == 2 else { return (name, nil) }
        let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        return (name, value)
    }

    private static func takeName(_ scanner: inout Substring) -> String? {
        let name = scanner.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "*" }
        guard !name.isEmpty else { return nil }
        scanner = scanner.dropFirst(name.count)
        return String(name)
    }
}
