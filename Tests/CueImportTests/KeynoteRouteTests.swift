import CoreServices
import CueCore
import Foundation
import Testing
@testable import CueImport

/// Runs only when Keynote is installed, running, and this process may
/// already control it, so a test never triggers a permission prompt.
@Suite("Keynote route")
struct KeynoteRouteTests {
    static let key = TempFolder.repoRoot.appendingPathComponent("fixtures/private/private-deck.key")

    static var permitted: Bool {
        guard KeynoteExporter().isInstalled, FileManager.default.fileExists(atPath: key.path) else { return false }
        let target = NSAppleEventDescriptor(bundleIdentifier: KeynoteExporter.bundleID)
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false) == noErr
    }

    @Test(.enabled(if: KeynoteRouteTests.permitted), .timeLimit(.minutes(4)))
    func keynoteFilesConvertThroughPowerPoint() async throws {
        let folder = TempFolder()
        let copy = try folder.file("Talk.key", try Data(contentsOf: Self.key))
        let prepared = try await ImportService().prepare(copy)
        #expect(prepared.report?.route == "Keynote → PowerPoint")
        let document = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(document.structure.slides.count > 1)
    }

    @Test func keyWithoutKeynoteShowsItsPreview() async throws {
        guard FileManager.default.fileExists(atPath: Self.key.path) else { return }
        let folder = TempFolder()
        let copy = try folder.file("Talk.key", try Data(contentsOf: Self.key))
        var service = ImportService()
        service.keynote = KeynoteExporter.unavailable
        let prepared = try await service.prepare(copy)
        #expect(prepared.report?.isPresentOnly == true)
        #expect(try DeckDocument(contentsOf: prepared.htmlURL).structure.slides.count == 1)
    }
}
