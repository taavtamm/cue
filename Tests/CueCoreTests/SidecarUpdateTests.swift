import Foundation
import Testing
@testable import CueCore

/// `deck.cue.json` is shared by display roles, timings and the talk length.
/// Updates must merge, never wipe.
@Suite("Sidecar updates")
struct SidecarUpdateTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "cue-sidecar-\(UUID().uuidString).cue.json")
    }

    @Test func separateUpdatesMergeInsteadOfOverwriting() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try CueSidecar.update(at: url) { $0.displayRoles = ["set": ["1": "stage"]] }
        try CueSidecar.update(at: url) { $0.targetDuration = 600 }
        let sidecar = try CueSidecar.load(from: url)
        #expect(sidecar.displayRoles == ["set": ["1": "stage"]])
        #expect(sidecar.targetDuration == 600)
    }

    @Test func unknownKeysSurviveAnUpdate() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(#"{"version": 1, "allowedHosts": [], "fromANewerCue": {"x": 1}}"#.utf8).write(to: url)
        try CueSidecar.update(at: url) { $0.targetDuration = 600 }
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect(object["fromANewerCue"] != nil)
        #expect(object["targetDuration"] as? Double == 600)
    }

    @Test func anUnreadableSidecarIsNeverReplaced() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let damaged = Data(#"{"targetDuration": "not a number", "displayRoles": {"set": {"1": "stage"}}}"#.utf8)
        try damaged.write(to: url)
        #expect(throws: (any Error).self) {
            try CueSidecar.update(at: url) { $0.targetDuration = 60 }
        }
        #expect(try Data(contentsOf: url) == damaged)
    }
}
