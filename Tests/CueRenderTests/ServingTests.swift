import CueCore
import Foundation
import Testing
@testable import CueRender

@Suite("Serving the deck folder")
struct ServingTests {
    let folder = DeckFolder(root: FileManager.default.temporaryDirectory.appending(path: "cue-folder-test"))

    @Test func resolvesFilesInsideTheFolder() throws {
        let file = try folder.resolve(urlPath: "/images/a.png").get()
        #expect(file.path == folder.root.appending(path: "images/a.png").path)
    }

    static let hostilePaths = [
        "/../secret.txt", "/a/../../etc/passwd", "/%2E%2E/x", "/a/%2e%2e/%2e%2e/x", "/./a", "/a\\b", "/",
    ]

    @Test(arguments: hostilePaths)
    func refusesPathsThatLeaveOrConfuse(_ path: String) {
        #expect(throws: DeckFolderError.self) { try folder.resolve(urlPath: path).get() }
    }

    @Test func refusesSymlinksThatPointOutside() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "cue-link-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let link = root.appending(path: "escape")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: URL(filePath: "/etc"))
        let linked = DeckFolder(root: root)
        #expect(throws: DeckFolderError.outsideFolder) { try linked.resolve(urlPath: "/escape/hosts").get() }
    }

    @Test func servedDocumentDropsOnlyThePlayerScript() throws {
        let source = try Fixture.demo-deckSource()
        let range = try #require(source.structure.replacedPlayerScript)
        let served = ServedDocument.html(source: source.sourceText, structure: source.structure)
        let original = source.sourceText as NSString

        #expect(!served.contains("function yCn("))
        #expect(served.contains(ServedDocument.replacementMarker))
        #expect(served.contains("id=\"deck-motion\""))
        #expect(served.hasPrefix(original.substring(to: range.start)))
        #expect(served.hasSuffix(original.substring(from: range.end)))
    }

    @Test func networkRulesBlockEverythingButTheDeckAndAllowedHosts() throws {
        let json = NetworkRules.json(allowedHosts: ["fonts.gstatic.com"])
        let rules = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        let filters = rules.compactMap { ($0["trigger"] as? [String: String])?["url-filter"] }
        #expect(filters.first == ".*")
        #expect(filters.contains("^cue-deck:"))
        #expect(filters.contains("^https://fonts\\.gstatic\\.com/"))
        #expect(!NetworkRules.json(allowedHosts: []).contains("https"))
    }
}
