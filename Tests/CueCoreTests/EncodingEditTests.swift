import Foundation
import Testing
@testable import CueCore

/// Edits keep the file's encoding, byte-order mark and line endings.
@Suite("Edits and file encodings")
struct EncodingEditTests {
    @Test func bomAndCRLFSurviveAnEdit() throws {
        var document = try Editing.document("bom-crlf.html")
        let h1 = try Editing.path(in: document, tag: "h1")
        let result = try document.apply(.setText(h1, "Été 🎉\nnew line"))
        let data = try document.encodedData()
        #expect(data.starts(with: [0xEF, 0xBB, 0xBF]))
        #expect(document.source.contains("Été 🎉\r\nnew line"))
        #expect(!document.source.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
        Editing.expectLocalBytes(before: document.originalData, after: data,
                                 beforeText: try String(contentsOf: document.fileURL, encoding: .utf8)
                                     .replacingOccurrences(of: "\u{FEFF}", with: ""),
                                 edit: result.edit)
    }

    @Test func latin1KeepsItsEncodingAndEscapesWhatItCannotStore() throws {
        var document = try Editing.document("latin1.html")
        let h1 = try Editing.path(in: document, tag: "h1")
        try document.apply(.setText(h1, "Café — ☕"))
        // é and — exist in Windows-1252; ☕ doesn't, so it becomes a reference.
        #expect(document.source.contains("<h1>Café — &#x2615;</h1>"))
        let data = try document.encodedData()
        #expect(String(data: data, encoding: .windowsCP1252)?.contains("Café") == true)
        #expect(data.contains(0xE9))
    }

    @Test func codeContextsRefuseWhatTheEncodingCannotStore() throws {
        var document = try Editing.document("latin1.html")
        #expect(throws: EditError.unencodable("☕")) {
            try document.apply(.setOverride(selector: "h1::after", property: "content", value: "\"☕\""))
        }
    }

    @Test func unchangedSaveIsByteIdenticalAndUndoGetsBackThere() throws {
        for fixture in ["demo-deck.html", "bom-crlf.html", "latin1.html", "reveal.html"] {
            var document = try Editing.document(fixture)
            #expect(try document.encodedData() == document.originalData, "\(fixture) unchanged")
            let body = try Editing.path(in: document, tag: "body")
            try document.apply(.setAttribute(body, name: "data-x", value: "1"))
            #expect(try document.encodedData() != document.originalData)
            try document.undo()
            #expect(try document.encodedData() == document.originalData, "\(fixture) after undo")
            let target = document.fileURL.deletingLastPathComponent().appendingPathComponent("saved.html")
            try document.save(to: target)
            #expect(try Data(contentsOf: target) == document.originalData)
        }
    }
}
