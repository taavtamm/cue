import Foundation

/// Converts one presentation format into an `ImportedDeck`. Pictures go
/// into `assets`; anything not carried across exactly goes into `report`.
public protocol DeckImporter: Sendable {
    func makeDeck(from url: URL, assets: AssetStore, report: inout ImportReport) async throws -> ImportedDeck
}
