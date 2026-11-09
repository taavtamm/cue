import Foundation
import Testing
@testable import CueCore

/// The locality property for milestone B's operations: random moves,
/// resizes, inserts, deletes and formatted-text edits on the demo deck,
/// each changing only its own region and undoing to the exact bytes.
@Suite("Random hand edits")
struct HandEditingRandomTests {
    static func cases(for document: DeckDocument, count: Int, seed: UInt64) -> [RandomEditTests.Case] {
        var random = SeededGenerator(seed: seed)
        let slidePaths = Set(document.structure.slides.map(\.elementPath))
        let body = document.sourceMap.elements.filter { element in
            element.startTag != nil && element.path.first == 1 && !slidePaths.contains(element.path)
                && !MappedElement.rawTextTags.contains(element.tag) && element.tag != "template"
                && element.path.count > 3
        }
        // Not links (a link in a link makes the parser restructure, and Cue rightly reloads),
        // and nothing inside a drawing, where Cue refuses formatted text.
        let inDrawing = Set(body.filter { ["svg", "math"].contains($0.tag) }.map(\.path))
        let containers = body.filter { element in
            !element.isLeaf && element.innerRange != nil && element.tag != "a"
                && !(0...element.path.count).contains { inDrawing.contains(Array(element.path.prefix($0))) }
        }
        return (0..<count).map { number in
            let operation: EditOperation
            switch number % 4 {
            case 0:
                let element = body.randomElement(using: &random)!
                operation = .setStyles(element.path, [
                    StyleChange("translate", "\(number)px \(-number)px"), StyleChange("width", "\(200 + number)px"),
                ])
            case 1:
                let slide = Int.random(in: 0..<document.structure.slides.count, using: &random)
                let html = ElementTemplate.textBox(text: "Box \(number) & <more>", fontSize: 40, fontFamily: nil)
                    .html(id: "cue-test-\(number)", frame: CGRect(x: 100, y: 100, width: 400, height: 80))
                operation = .insertElement(slide: slide, html: html)
            case 2:
                operation = .deleteElement(body.randomElement(using: &random)!.path)
            default:
                let element = containers.randomElement(using: &random)!
                operation = .setInnerHTML(element.path, "Bold <b>\(number)</b> and a <a href=\"https://cue.app\">link</a>")
            }
            return RandomEditTests.Case(number: number, operation: operation)
        }
    }

    @Test func randomHandEditsStayLocalAndUndoExactly() async throws {
        let original = try Editing.document("demo-deck.html")
        let cases = Self.cases(for: original, count: 24, seed: 0xB0B)
        let failures = try await withThrowingTaskGroup(of: [String].self) { group in
            for testCase in cases { group.addTask { try RandomEditTests.check(testCase, on: original) } }
            var all: [String] = []
            for try await problems in group { all += problems }
            return all
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }
}
