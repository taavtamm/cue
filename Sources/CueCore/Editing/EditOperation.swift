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

    /// Edits with the same key, made in quick succession, undo as one.
    var coalescingKey: String? {
        switch self {
        case .setText(let path, _): "text \(path)"
        case .setAttribute(let path, let name, _): "attr \(path) \(name)"
        case .setStyle(let path, let property, _): "style \(path) \(property)"
        case .setNotes(let slide, _): "notes \(slide)"
        case .setOverride(let selector, let property, _): "override \(selector) \(property)"
        default: nil
        }
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
