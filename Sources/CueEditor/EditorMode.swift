/// The editor's three views of a deck, switched in the toolbar.
public enum EditorMode: String, CaseIterable, Sendable {
    /// The real slide with selection, inspector and timeline.
    case design
    /// The slide's HTML source.
    case html
    /// Every slide's label and notes as a list.
    case outline

    public var title: String {
        switch self {
        case .design: "Design"
        case .html: "HTML"
        case .outline: "Outline"
        }
    }
}
