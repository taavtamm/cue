import AppKit
import CueCore
@testable import CueEditor
import Foundation
import Testing
@testable import CueRender

@Suite("Thumbnails", .serialized)
@MainActor
struct ThumbnailTests {
    @Test func thumbnailsAreRealRendersAndNeverStartEmbeds() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let store = ThumbnailStore(canvas: document.structure.canvas, width: 320)
        defer { store.close() }
        await store.load(document)
        let deadline = Date().addingTimeInterval(60)
        while store.images.count < document.structure.slides.count, Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(store.images.count == 12)
        #expect(store.images[0]?.size.width == 320)
        let frames = try await store.renderer.evaluateInBridge("return document.querySelectorAll('iframe').length")
        #expect(frames as? Int == 0)
    }
}
