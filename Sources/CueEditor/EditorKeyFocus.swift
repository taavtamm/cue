/// Which part of the editor the keyboard belongs to, for keys with no text
/// field focused: arrows step through slides, Delete removes the slide when
/// the sidebar was clicked last.
public enum EditorKeyFocus: Sendable {
    case sidebar, canvas
}
