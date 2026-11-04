import Foundation
import Testing
@testable import CueCore

@Suite("New Presentation template")
struct BlankDeckTemplateTests {
    @Test func opensAsACueDeckWithOneTitleSlide() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "cue-blank-\(UUID().uuidString).html")
        defer { try? FileManager.default.removeItem(at: url) }
        try BlankDeckTemplate.html(title: "Quarterly <review> & plan").write(to: url, atomically: true, encoding: .utf8)

        let document = try DeckDocument(contentsOf: url)
        #expect(document.structure.adapter == .cue)
        #expect(document.structure.renderMode == .cueDriven)
        #expect(document.structure.slides.count == 1)
        #expect(document.structure.canvas == .hd)
        #expect(document.structure.slides[0].label == "Quarterly <review> & plan")
        #expect(document.structure.slides[0].notes.isEmpty)
    }

    @Test func savesBackByteIdenticalWhenUnchanged() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "cue-blank-\(UUID().uuidString).html")
        defer { try? FileManager.default.removeItem(at: url) }
        let html = BlankDeckTemplate.html()
        try html.write(to: url, atomically: true, encoding: .utf8)
        let document = try DeckDocument(contentsOf: url)
        try document.save()
        #expect(try String(contentsOf: url, encoding: .utf8) == html)
    }

    @Test func hasNoScriptsAndNoNetwork() {
        let html = BlankDeckTemplate.html().lowercased()
        #expect(!html.contains("<script"))
        #expect(!html.contains("http://") && !html.contains("https://"))
        #expect(!html.contains("@import") && !html.contains("url("))
    }

    @Test func fontNamesCannotBreakOutOfTheStyleRule() {
        #expect(BlankDeckTemplate.fontStack("System") == BlankDeckTemplate.systemFontStack)
        #expect(BlankDeckTemplate.fontStack("Inter Display").hasPrefix("\"Inter Display\", "))
        let hostile = BlankDeckTemplate.fontStack("x\"; } body { background: url(https://evil) } {")
        #expect(!hostile.contains("{") && !hostile.contains(";") && !hostile.contains("("))
    }
}

/// Opt-in: `CUE_TEMPLATE_OUT=/path/deck.html swift test --filter writesTheTemplate`
/// writes the blank deck there, to open it in the app.
@Test(.enabled(if: ProcessInfo.processInfo.environment["CUE_TEMPLATE_OUT"] != nil))
func writesTheTemplateForManualChecks() throws {
    let path = try #require(ProcessInfo.processInfo.environment["CUE_TEMPLATE_OUT"])
    try BlankDeckTemplate.html(title: "Untitled Presentation").write(toFile: path, atomically: true, encoding: .utf8)
}
