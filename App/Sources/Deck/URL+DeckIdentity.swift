import Foundation

extension URL {
    /// One spelling per file: `/var` vs `/private/var`, `./`, symlinks. Decks
    /// are matched on this so a file never opens in two windows.
    var deckIdentity: URL { standardizedFileURL.resolvingSymlinksInPath() }
}
