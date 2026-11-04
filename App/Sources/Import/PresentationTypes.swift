import UniformTypeIdentifiers

/// The file types Cue opens: HTML decks, and presentations it converts.
enum PresentationTypes {
    static var all: [UTType] {
        [.html] + ["pptx", "ppt", "key", "odp", "pdf"].compactMap { UTType(filenameExtension: $0) }
    }
}
