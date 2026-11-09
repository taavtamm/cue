import Foundation
import Testing
@testable import CueCore

@Suite("DeckDocument")
struct DeckDocumentTests {
    @Test(arguments: ["demo-deck.html", "bom-crlf.html", "latin1.html", "reveal.html"])
    func unchangedSaveIsByteIdentical(file: String) throws {
        let url = try Fixtures.copy(file)
        let original = try Data(contentsOf: url)
        let document = try DeckDocument(contentsOf: url)
        #expect(!document.isModified)
        let target = url.deletingLastPathComponent().appendingPathComponent("saved.html")
        try document.save(to: target)
        #expect(try Data(contentsOf: target) == original)
    }

    @Test func opensTheFixtureDeck() throws {
        let document = try DeckDocument(contentsOf: try Fixtures.copy("demo-deck.html"))
        #expect(document.structure.adapter == .claudeDesign)
        #expect(document.structure.slides.count == 12)
        #expect(document.encoding == .utf8)
        #expect(document.sidecarURL.lastPathComponent == "demo-deck.cue.json")
    }

    @Test func decodesDeclaredCharset() throws {
        let document = try DeckDocument(contentsOf: try Fixtures.copy("latin1.html"))
        #expect(document.encoding == .windowsCP1252)
        #expect(document.structure.slides.first?.label == "Café")
    }

    @Test func keepsByteOrderMarkFilesReadable() throws {
        let document = try DeckDocument(contentsOf: try Fixtures.copy("bom-crlf.html"))
        #expect(document.structure.slides.first?.label == "Été 🎉")
    }

    @Test func editedSourceIsWrittenAndReanalysed() throws {
        let url = try Fixtures.copy("cue-convention.html")
        var document = try DeckDocument(contentsOf: url)
        try document.replaceSource(document.source.replacingOccurrences(of: "Hello, Cue", with: "Hi"))
        #expect(document.isModified)
        #expect(document.structure.slides[0].label == "Hi")
        try document.save()
        #expect(try String(contentsOf: url, encoding: .utf8).contains("<h1>Hi</h1>"))
    }

    @Test func sidecarRoundTrips() throws {
        let url = try Fixtures.copy("plain-page.html").deletingPathExtension().appendingPathExtension("cue.json")
        #expect(try CueSidecar.load(from: url) == CueSidecar())
        var sidecar = CueSidecar()
        sidecar.targetDuration = 600
        try sidecar.save(to: url)
        #expect(try CueSidecar.load(from: url) == sidecar)
    }
}
