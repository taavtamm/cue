import UniformTypeIdentifiers

/// The file types Cue opens: HTML decks, and presentations it converts.
enum PresentationTypes {
    /// File name extensions Cue opens, lowercased.
    static let extensions = ["html", "htm", "pptx", "ppt", "key", "odp", "pdf"]

    static var all: [UTType] {
        [.html] + ["pptx", "ppt", "key", "odp", "pdf"].compactMap { UTType(filenameExtension: $0) }
    }
}
