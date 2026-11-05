import Foundation

/// Where create_deck writes a new presentation: a file named after its
/// title in the chosen folder (default: Cue's save folder or
/// ~/Documents/Cue Decks), inside the user's home folder, never over an
/// existing file ("Pitch.html", then "Pitch 2.html", …).
public enum NewDeckLocation {
    public static func defaultFolder(saveFolder: URL?, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        saveFolder ?? home.appending(path: "Documents/Cue Decks", directoryHint: .isDirectory)
    }

    public static func url(
        title: String, in folder: URL, home: URL = FileManager.default.homeDirectoryForCurrentUser,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) throws -> URL {
        let folder = folder.standardizedFileURL.resolvingSymlinksInPath()
        let homePath = home.standardizedFileURL.resolvingSymlinksInPath().path
        guard folder.path == homePath || folder.path.hasPrefix(homePath + "/") else {
            throw CueMCPError.invalid("New decks go inside your home folder; \(folder.path) isn't.")
        }
        let name = fileName(for: title)
        var candidate = folder.appending(path: "\(name).html")
        var number = 2
        while exists(candidate) {
            candidate = folder.appending(path: "\(name) \(number).html")
            number += 1
        }
        return candidate
    }

    /// A safe file name: no slashes or colons, no leading dots, not empty.
    static func fileName(for title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "Untitled Presentation" : String(cleaned.prefix(120))
    }
}
