import Foundation
import Testing
@testable import CueCore

@Suite("Source map")
struct SourceMapTests {
    @Test func everyElementSlicesBackToItsTags() throws {
        let document = try Editing.document("demo-deck.html")
        let text = SourceText(document.source)
        var checked = 0
        for element in document.sourceMap.elements {
            guard let range = element.range, let startTag = element.startTag else { continue }
            let whole = text.slice(range).lowercased()
            #expect(whole.hasPrefix("<\(element.tag.lowercased())"))
            #expect(text.slice(startTag).hasSuffix(">"))
            if let endTag = element.endTag {
                #expect(text.slice(endTag).lowercased() == "</\(element.tag.lowercased())>")
                #expect(endTag.end == range.end)
            }
            checked += 1
        }
        #expect(checked > 500)
    }

    @Test func attributeValueRangesHoldTheRawValue() throws {
        let document = try Editing.document("demo-deck.html")
        let text = SourceText(document.source)
        for element in document.sourceMap.elements.prefix(400) {
            for (name, location) in element.attributeLocations {
                guard let valueRange = location.valueRange, let value = element.attributes[name] else { continue }
                let raw = text.slice(valueRange)
                if !raw.contains("&") { #expect(raw == value, "\(element.tag) \(name)") }
            }
        }
    }

    @Test func cueIDsAndPathsResolveToTheSameElement() throws {
        let document = try Editing.document("cue-convention.html")
        for element in document.sourceMap.elements {
            #expect(document.element(cueID: element.cueID) == element)
            #expect(document.sourceMap.element(at: element.path) == element)
        }
    }

    @Test func manifestLeavesOutTheReplacedPlayerScript() throws {
        let document = try Editing.document("demo-deck.html")
        let manifest = document.liveManifest
        #expect(manifest.count == document.sourceMap.elements.count - 1)
        let scripts = document.sourceMap.elements.filter { $0.tag == "script" }.count
        #expect(manifest.filter { $0.tag == "script" }.count == scripts - 1)
    }
}
