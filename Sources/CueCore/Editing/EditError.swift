import Foundation

/// Why Cue refused an edit. Refusing beats writing something that would
/// corrupt the file or change more than the user asked.
public enum EditError: Error, Equatable, Sendable {
    case elementNotFound
    case elementHasNoSource
    /// Text edits replace an element's whole content; elements with child
    /// elements need an element-level edit instead.
    case notALeaf
    /// `<script>` and `<style>` contents are code, not text.
    case rawTextElement(String)
    case voidElement(String)
    case slideOutOfRange(Int)
    case lastSlide
    /// The file's encoding can't store a character, and this context has no escape for it.
    case unencodable(Character)
    case invalidAttributeName(String)
    case invalidStyleProperty(String)
    case unsupported(String)
    case patchOutOfRange
    case malformedSource(String)
    case nothingToUndo
    case nothingToRedo
}
