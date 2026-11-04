import Foundation

/// A deliberately small CSS selector matcher, used to check a deck's declared
/// slide selector against the parsed tree. Supports tag, `.class`, `#id`,
/// `[attr]`, `[attr="value"]`, descendant (` `) and child (`>`) combinators,
/// and comma lists. Anything else fails to parse and returns nil, so callers
/// fall back instead of guessing.
public struct SimpleSelector: Sendable {
    struct Compound: Sendable {
        var tag: String?
        var id: String?
        var classes: [String] = []
        var attributes: [(name: String, value: String?)] = []
    }
    enum Combinator: Sendable { case descendant, child }
    /// Right-to-left: `steps[0]` is the subject, each later one an ancestor.
    typealias Chain = [(compound: Compound, combinator: Combinator)]

    private let chains: [Chain]

    public init?(_ text: String) {
        var chains: [Chain] = []
        for part in text.split(separator: ",") {
            guard let chain = SelectorParser.chain(String(part)) else { return nil }
            chains.append(chain)
        }
        guard !chains.isEmpty else { return nil }
        self.chains = chains
    }

    /// All matching descendants of `root`, in document order, with paths.
    public func matches(in root: HTMLNode) -> [(node: HTMLNode, path: ElementPath)] {
        var result: [(HTMLNode, ElementPath)] = []
        func walk(_ node: HTMLNode, _ path: ElementPath, _ ancestors: [HTMLNode]) {
            for (index, child) in node.children.enumerated() {
                let childPath = path + [index]
                if chains.contains(where: { Self.match($0, child, ancestors: ancestors + [node]) }) {
                    result.append((child, childPath))
                }
                walk(child, childPath, ancestors + [node])
            }
        }
        walk(root, [], [])
        return result
    }

    private static func match(_ chain: Chain, _ node: HTMLNode, ancestors: [HTMLNode]) -> Bool {
        guard let first = chain.first, matches(first.compound, node) else { return false }
        var remaining = ancestors[...]
        var combinator = first.combinator
        for step in chain.dropFirst() {
            switch combinator {
            case .child:
                guard let parent = remaining.popLast(), matches(step.compound, parent) else { return false }
            case .descendant:
                guard let index = remaining.lastIndex(where: { matches(step.compound, $0) }) else { return false }
                remaining = remaining[..<index]
            }
            combinator = step.combinator
        }
        return true
    }

    private static func matches(_ compound: Compound, _ node: HTMLNode) -> Bool {
        if let tag = compound.tag, tag != "*", tag != node.tag { return false }
        if let id = compound.id, node["id"] != id { return false }
        if !compound.classes.allSatisfy(node.hasClass) { return false }
        for attribute in compound.attributes {
            guard let value = node[attribute: attribute.name] else { return false }
            if let expected = attribute.value, expected != value { return false }
        }
        return true
    }
}
