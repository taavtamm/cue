import CueCore
import Foundation

/// A slide's builds as the Animate tab edits them: each step's elements by
/// source path, so reordering or adding a step becomes one `setBuilds` edit.
public struct BuildPlan: Sendable, Equatable {
    public struct Step: Sendable, Equatable, Identifiable {
        public let id: Int
        public var targets: [ElementPath]
        public var effect: String?
        /// "Headline", "Cards 01–04", … for the list.
        public var title: String
    }

    public var steps: [Step]
    /// False when a step's targets couldn't be traced back to the source
    /// (selectors Cue doesn't resolve); the list is then read-only.
    public let isEditable: Bool

    /// Effects Cue's players know, in the order the menu shows them.
    public static let effects = ["fade", "rise", "drop", "left", "right", "scale", "pop"]

    public init(slide: SlideInfo, map: SourceMap, tree: HTMLNode) {
        var editable = true
        steps = slide.builds.enumerated().map { index, build in
            let paths = build.targets.flatMap { Self.resolve($0, under: slide.elementPath, in: map) }
            if paths.isEmpty { editable = false }
            let names = paths.compactMap { tree.node(at: $0).map(Self.name) }.filter { !$0.isEmpty }
            let title = names.isEmpty ? build.targets.joined(separator: ", ") : names.prefix(2).joined(separator: ", ")
                + (names.count > 2 ? " +\(names.count - 2)" : "")
            return Step(id: index, targets: paths, effect: build.effect, title: title)
        }
        isEditable = editable
    }

    public var specs: [BuildSpec] { steps.map { BuildSpec(targets: $0.targets, effect: $0.effect) } }

    /// A new last step revealing one element.
    public mutating func append(_ target: ElementPath, effect: String? = "fade") {
        steps.append(Step(id: steps.count, targets: [target], effect: effect, title: ""))
    }

    public mutating func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard steps.indices.contains(index), steps.indices.contains(target) else { return }
        steps.swapAt(index, target)
    }

    /// Elements matching a `[name="value"]` selector inside the slide. Other
    /// selector shapes aren't resolved; they leave the plan read-only.
    static func resolve(_ selector: String, under slide: ElementPath, in map: SourceMap) -> [ElementPath] {
        guard selector.hasPrefix("["), selector.hasSuffix("]"), let equals = selector.firstIndex(of: "=") else {
            return []
        }
        let name = String(selector[selector.index(after: selector.startIndex)..<equals])
        let value = selector[selector.index(after: equals)..<selector.index(before: selector.endIndex)]
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return map.elements
            .filter { $0.path.starts(with: slide) && $0.path != slide && $0.attributes[name] == value }
            .map(\.path)
    }

    private static func name(_ node: HTMLNode) -> String {
        let label = node.attributes["data-label"] ?? node.attributes["aria-label"] ?? node.text
        let words = label.isEmpty ? node.descendants.lazy.map(\.text).first { !$0.isEmpty } : label
        guard let words else { return node.tag }
        return words.count > 24 ? String(words.prefix(23)) + "…" : words
    }
}
