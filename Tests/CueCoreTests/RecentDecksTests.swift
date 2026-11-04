import Foundation
import Testing
@testable import CueCore

@Suite("Recent decks and Welcome thumbnails")
struct RecentDecksTests {
    @Test func dropsMissingFilesAndDuplicatesKeepingOrder() {
        let a = URL(filePath: "/decks/a.html"), b = URL(filePath: "/decks/b.html")
        let gone = URL(filePath: "/decks/gone.html"), aAgain = URL(filePath: "/decks/./a.html")
        let pruned = RecentDecks.pruned([a, gone, b, aAgain]) { $0 != gone }
        #expect(pruned == [a, b])
    }

    @Test func capsTheList() {
        let urls = (0..<20).map { URL(filePath: "/decks/\($0).html") }
        #expect(RecentDecks.pruned(urls, limit: 5) { _ in true }.count == 5)
    }

    @Test func cacheKeyChangesWithPathOrModificationDate() {
        let url = URL(filePath: "/decks/a.html")
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let key = ThumbnailCacheKey(url: url, modified: date)
        #expect(key == ThumbnailCacheKey(url: url, modified: date))
        #expect(key != ThumbnailCacheKey(url: url, modified: date.addingTimeInterval(1)))
        #expect(key != ThumbnailCacheKey(url: URL(filePath: "/decks/b.html"), modified: date))
        #expect(key.fileName.hasSuffix(".png") && key.fileName.count == 20)
    }

    @Test func cacheKeyIsStableAcrossLaunches() {
        // FNV-1a of a fixed string: a regression guard against using hashValue.
        #expect(ThumbnailCacheKey.fnv1a("cue") == ThumbnailCacheKey.fnv1a("cue"))
        #expect(ThumbnailCacheKey.fnv1a("") == 0xcbf2_9ce4_8422_2325)
    }

    @Test func readsTheModificationDateFromDisk() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "cue-recent-\(UUID().uuidString).html")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        let before = try #require(ThumbnailCacheKey(fileAt: url))
        let later = Date().addingTimeInterval(60)
        try FileManager.default.setAttributes([.modificationDate: later], ofItemAtPath: url.path)
        let after = try #require(ThumbnailCacheKey(fileAt: url))
        #expect(before != after)
        try FileManager.default.removeItem(at: url)
        #expect(ThumbnailCacheKey(fileAt: url) == nil)
    }
}
