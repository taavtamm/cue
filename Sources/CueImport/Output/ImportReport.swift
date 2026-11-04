import Foundation

/// What an import couldn't bring across exactly. Shown after opening.
public struct ImportReport: Sendable, Equatable {
    public struct Note: Sendable, Equatable, Hashable {
        /// 1-based slide number, or nil for the whole file.
        public let slide: Int?
        public let message: String
        public init(slide: Int?, message: String) {
            self.slide = slide
            self.message = message
        }
    }

    public var sourceName: String
    public var route: String
    public private(set) var notes: [Note] = []
    public var isPresentOnly = false
    /// Where the output went, if not next to the original.
    public var outputRelocated: URL?

    public init(sourceName: String, route: String) {
        self.sourceName = sourceName
        self.route = route
    }

    public mutating func note(_ message: String, slide: Int? = nil) {
        let note = Note(slide: slide, message: message)
        if !notes.contains(note) { notes.append(note) }
    }

    /// "Slide 4: chart shown as a picture" style lines, grouped per message.
    public var summaryLines: [String] {
        var order: [String] = []
        var slides: [String: [Int]] = [:]
        for note in notes {
            if slides[note.message] == nil { order.append(note.message) }
            slides[note.message, default: []].append(contentsOf: note.slide.map { [$0] } ?? [])
        }
        return order.map { message in
            let list = Array(Set(slides[message] ?? [])).sorted()
            guard !list.isEmpty else { return message }
            let prefix = list.count == 1 ? "Slide \(list[0])" : "Slides " + list.map(String.init).joined(separator: ", ")
            return "\(prefix): \(message)"
        }
    }
}
