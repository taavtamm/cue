import Foundation
import Testing
@testable import CueCore

/// The brief's locality test: 50 random single edits on the demo deck,
/// each touching only its own region, re-parsing to the expected structure,
/// and undoing back to the exact original bytes.
@Suite("Random single edits")
struct RandomEditTests {
    struct Case: Sendable {
        let number: Int
        let operation: EditOperation
    }

    static func cases(for document: DeckDocument, count: Int, seed: UInt64) -> [Case] {
        var random = SeededGenerator(seed: seed)
        let body = document.sourceMap.elements.filter { element in
            element.startTag != nil && element.path.first == 1 // inside <body>
                && !MappedElement.rawTextTags.contains(element.tag) && element.tag != "template"
        }
        let leaves = body.filter { $0.isLeaf && $0.innerRange != nil && !MappedElement.voidTags.contains($0.tag) }
        let styled = body.filter { $0.attributes["style"] != nil }
        return (0..<count).map { number in
            let text = "Edit \(number): “quotes” & <tags>"
            let operation: EditOperation
            switch number % 4 {
            case 0: operation = .setText(leaves.randomElement(using: &random)!.path, text)
            case 1:
                let element = body.randomElement(using: &random)!
                operation = .setAttribute(element.path, name: "data-cue-test", value: text)
            case 2:
                let element = styled.randomElement(using: &random)!
                // Change a property the element already has, or add one.
                let existing = StyleDeclarations(element.attributes["style"] ?? "").declarations.first?.property
                operation = number % 8 == 2 || existing == nil
                    ? .setStyle(element.path, property: "outline", value: "2px solid rgb(47, 123, 255)")
                    : .setStyle(element.path, property: existing!, value: nil)
            default:
                let slide = Int.random(in: 0..<document.structure.slides.count, using: &random)
                operation = .setNotes(slide: slide, text: text)
            }
            return Case(number: number, operation: operation)
        }
    }

    @Test func fiftyRandomEditsStayLocalAndUndoExactly() async throws {
        let original = try Editing.document("demo-deck.html")
        let cases = Self.cases(for: original, count: 50, seed: 0xC0E)
        // Each case re-parses the 2 MB deck twice; run them side by side.
        let failures = try await withThrowingTaskGroup(of: [String].self) { group in
            for testCase in cases {
                group.addTask { try Self.check(testCase, on: original) }
            }
            var all: [String] = []
            for try await problems in group { all += problems }
            return all
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    /// Text edits stay inside the element; attribute, style and notes edits
    /// inside the start tag (notes live in the slide's start tag here).
    static func allowedRegion(for operation: EditOperation, in document: DeckDocument) -> SourceRange? {
        let map = document.sourceMap
        switch operation {
        case .setText(let path, _): return map.element(at: path)?.innerRange
        case .setAttribute(let path, _, _), .setStyle(let path, _, _): return map.element(at: path)?.startTag
        case .setNotes(let slide, _): return map.element(at: document.structure.slides[slide].elementPath)?.startTag
        case .setStyles(let path, _): return map.element(at: path)?.startTag
        case .setInnerHTML(let path, _): return map.element(at: path)?.innerRange
        case .deleteElement(let path):
            guard let range = map.element(at: path)?.range else { return nil }
            return SourceRange(start: SourceText(document.source).whitespaceStart(before: range.start), end: range.end)
        case .insertElement(let slide, _):
            let editor = SourceEditor(source: document.source, root: document.tree, map: map,
                                      structure: document.structure, encoding: document.encoding)
            guard let end = (try? editor.canvasContainer(ofSlide: slide))?.endTag else { return nil }
            return SourceRange(start: SourceText(document.source).whitespaceStart(before: end.start), end: end.start)
        default: return nil
        }
    }

    /// Returns what went wrong, if anything. Kept free of `#expect` so it can
    /// run on any thread.
    static func check(_ testCase: Case, on original: DeckDocument) throws -> [String] {
        var problems: [String] = []
        var document = original
        let result = try document.apply(testCase.operation)
        let name = "case \(testCase.number) \(testCase.operation)"
        guard result.edit.touchedRange != nil else { return ["\(name): made no patch"] }
        // The region the edit may change, taken from the original file, not from the patch.
        guard let touched = allowedRegion(for: testCase.operation, in: original) else { return ["\(name): no region"] }

        let oldUnits = Array(original.source.utf16)
        let tailLength = oldUnits.count - touched.end
        if !Editing.isLocal(oldUnits, Array(document.source.utf16), head: touched.start, tail: tailLength) {
            problems.append("\(name): text changed outside the edit")
        }
        let (head, tail) = Editing.byteLengths(around: touched, in: original.source)
        if !Editing.isLocal(Array(original.originalData), Array(try document.encodedData()), head: head, tail: tail) {
            problems.append("\(name): bytes changed outside the edit")
        }

        if document.structure.slides.count != 12 { problems.append("\(name): slide count changed") }
        if document.structure.slides.map(\.id) != original.structure.slides.map(\.id) {
            problems.append("\(name): slide ids")
        }
        if case .setNotes(let slide, let text) = testCase.operation, document.structure.slides[slide].notes != text {
            problems.append("\(name): notes not re-read")
        }
        // A reload is right only when the edit changed how the deck plays (e.g. removed a live embed).
        if result.live == .reload && !result.structureChanged { problems.append("\(name): a local edit asked for a reload") }

        try document.undo()
        if document.source != original.source { problems.append("\(name): undo didn't restore the text") }
        if try document.encodedData() != original.originalData {
            problems.append("\(name): undo didn't restore the bytes")
        }
        return problems
    }
}
