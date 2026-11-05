import Foundation

/// An edit to a deck, in terms a person or Claude would ask for. Cue turns
/// each into the smallest text patch on the source (see `SourceEditor`).
/// Elements are named by their path from `<html>` (see `SourceMap`).
public enum EditOperation: Sendable, Equatable, Codable {
    /// Replaces the text of an element that has no child elements.
    case setText(ElementPath, String)
    /// Sets an attribute, or removes it when `value` is nil.
    case setAttribute(ElementPath, name: String, value: String?)
    /// Sets one inline style property, keeping the others as written.
    case setStyle(ElementPath, property: String, value: String?)
    /// Speaker notes, wherever this deck keeps them.
    case setNotes(slide: Int, text: String)
    /// A new slide after `after` (-1 for the start). With no HTML, an empty
    /// slide that copies the deck's own slide wrappers.
    case addSlide(after: Int, html: String?)
    case deleteSlide(Int)
    /// Moves slide `from` so it ends up at index `to`.
    case moveSlide(from: Int, to: Int)
    /// The slide's build order: each step reveals these elements.
    case setBuilds(slide: Int, steps: [BuildSpec])
    /// A rule in Cue's own `<style id="cue-overrides">` block. The deck's
    /// stylesheet is never rewritten.
    case setOverride(selector: String, property: String, value: String?)
    /// Several inline style properties at once (a move or resize), as one
    /// undo step. Properties not listed keep their exact text.
    case setStyles(ElementPath, [StyleChange])
    /// New markup (a text box, image or shape) at the end of a slide's
    /// design canvas, the element that holds the slide's own boxes.
    case insertElement(slide: Int, html: String)
    /// Removes an element and the whitespace before it.
    case deleteElement(ElementPath)
    /// Replaces an element's content with formatted text (bold, italic,
    /// links, line breaks). The markup is sanitised first: see `RichTextSanitizer`.
    case setInnerHTML(ElementPath, String)
    /// Replaces a whole slide's markup (the slide element, start to end tag).
    case replaceSlide(Int, html: String)
    /// Raw patches on the current source. Used to revert one change set
    /// after later edits (`ChangeSetLedger`); one undo step like any other.
    case patches(SourceEdit)

    /// Edits with the same key, made in quick succession, undo as one.
    var coalescingKey: String? {
        switch self {
        case .setText(let path, _): "text \(path)"
        case .setAttribute(let path, let name, _): "attr \(path) \(name)"
        case .setStyle(let path, let property, _): "style \(path) \(property)"
        case .setNotes(let slide, _): "notes \(slide)"
        case .setOverride(let selector, let property, _): "override \(selector) \(property)"
        case .setStyles(let path, let changes): "styles \(path) \(changes.map(\.property).sorted())"
        case .setInnerHTML(let path, _): "text \(path)"
        default: nil
        }
    }
}

/// One inline style property to set, or remove when `value` is nil.
public struct StyleChange: Sendable, Equatable, Codable {
    public var property: String
    public var value: String?

    public init(_ property: String, _ value: String?) {
        self.property = property
        self.value = value
    }
}

/// One build step: the elements it reveals and how.
public struct BuildSpec: Sendable, Equatable, Codable {
    public var targets: [ElementPath]
    /// "fade", "rise", … Nil uses the deck's default.
    public var effect: String?

    public init(targets: [ElementPath], effect: String? = nil) {
        self.targets = targets
        self.effect = effect
    }
}
