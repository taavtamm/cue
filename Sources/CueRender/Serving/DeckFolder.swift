import Foundation

/// The one folder a deck may read from. Every request path is resolved
/// here, and anything that would leave the folder is refused.
public struct DeckFolder: Sendable, Equatable {
    /// Canonical folder URL, with symlinks resolved.
    public let root: URL

    public init(root: URL) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
    }

    /// Maps a URL path like `/images/a.png` to a file inside the folder.
    public func resolve(urlPath: String) -> Result<URL, DeckFolderError> {
        let decoded = urlPath.removingPercentEncoding ?? urlPath
        guard !decoded.contains("\0"), !decoded.contains("\\") else { return .failure(.invalidPath) }

        let components = decoded.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return .failure(.invalidPath) }
        guard !components.contains(where: { $0 == ".." || $0 == "." }) else { return .failure(.outsideFolder) }

        let candidate = components
            .reduce(root) { $0.appending(path: $1, directoryHint: .notDirectory) }
            .resolvingSymlinksInPath()
        guard contains(candidate) else { return .failure(.outsideFolder) }
        return .success(candidate)
    }

    /// True when `url` is the folder itself or sits anywhere below it.
    public func contains(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.hasPrefix(root.path + "/")
    }
}

public enum DeckFolderError: Error, Equatable {
    case invalidPath
    case outsideFolder
}
