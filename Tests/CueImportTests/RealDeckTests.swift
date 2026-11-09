import CueCore
import Foundation
import Testing
@testable import CueImport

/// The user's own deck in fixtures/private (git-ignored). Skipped when absent.
@Suite("Real PowerPoint deck")
struct RealDeckTests {
    static let pptx = TempFolder.privateDeck("pptx")
    static var available: Bool { FileManager.default.fileExists(atPath: pptx.path) }

    @Test(.enabled(if: RealDeckTests.available)) func convertsEverySlideWithItsNotes() async throws {
        let folder = TempFolder()
        let bytes = try Data(contentsOf: Self.pptx)
        let copy = try folder.file("Real.pptx", bytes)
        let zip = try ZipArchive(data: bytes)
        let expectedSlides = zip.entries.filter { $0.path.hasPrefix("ppt/slides/slide") && $0.path.hasSuffix(".xml") }.count
        let notesParts = zip.entries.filter { $0.path.hasPrefix("ppt/notesSlides/notesSlide") && $0.path.hasSuffix(".xml") }.count

        let prepared = try await ImportService().prepare(copy)
        #expect(try Data(contentsOf: copy) == bytes, "the original is never modified")
        let document = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(document.structure.adapter == .cue)
        #expect(document.structure.slides.count == expectedSlides)
        #expect(document.structure.slides.filter { !$0.notes.isEmpty }.count == notesParts)

        // Every slide has text or a picture.
        let sections = document.source.components(separatedBy: "<section data-cue-slide").dropFirst()
        #expect(sections.count == expectedSlides)
        for (index, section) in sections.enumerated() {
            #expect(section.contains("<img") || section.contains("<span"), "slide \(index + 1) is empty")
        }
        print("Real deck:", expectedSlides, "slides; report:", prepared.report?.summaryLines ?? [])
    }
}
