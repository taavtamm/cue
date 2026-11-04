import Foundation
@testable import CueCore

/// Test decks live in the repo's `fixtures/` folder. Tests read copies in a
/// temporary folder so nothing can modify the originals.
enum Fixtures {
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("fixtures")

    /// A fresh temporary copy of `fixtures/<name>`.
    static func copy(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cue-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: folder.appendingPathComponent(name), to: target)
        return target
    }

    static func source(_ name: String) throws -> String {
        try String(contentsOf: copy(name), encoding: .utf8)
    }

    static func input(_ name: String) throws -> AdapterInput {
        let source = try source(name)
        return AdapterInput(root: try HTMLParser().parse(source), source: source)
    }

    static func structure(_ name: String) throws -> DeckStructure {
        try AdapterRegistry.standard.structure(for: input(name))
    }
}
