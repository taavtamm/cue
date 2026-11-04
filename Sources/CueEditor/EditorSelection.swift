import CoreGraphics
import CueCore
import CueRender

/// The element the user selected on the slide.
public struct EditorSelection: Sendable, Equatable {
    public let element: MappedElement
    /// Where it is and how it looks. Nil until the page answers.
    public var inspection: ElementInspection?
    public var values = InspectorValues()
    public var breadcrumb: [String] = []
    /// What kind of thing this is, for the inspector header: "H1", "Text", …
    public var kind = ElementKind.box
    /// Its own words, shortened, for the inspector header.
    public var name = ""

    public var cueID: String { element.cueID }
    public var path: ElementPath { element.path }
    public var frame: CGRect? { inspection?.frame }

    public init(element: MappedElement) {
        self.element = element
    }
}

public enum ElementKind: Sendable, Equatable {
    case heading(Int), text, image, embed, slide, box

    public init(tag: String, hasEmbed: Bool, isLeaf: Bool) {
        if hasEmbed {
            self = .embed
        } else if tag.count == 2, tag.hasPrefix("h"), let level = Int(tag.dropFirst()) {
            self = .heading(level)
        } else if ["img", "svg", "picture", "video", "canvas"].contains(tag) {
            self = .image
        } else if tag == "section" {
            self = .slide
        } else {
            self = isLeaf ? .text : .box
        }
    }

    /// Short badge text, e.g. "H1".
    public var badge: String {
        switch self {
        case .heading(let level): "H\(level)"
        case .text: "T"
        case .image: "IMG"
        case .embed: "WEB"
        case .slide: "S"
        case .box: "BOX"
        }
    }

    public var title: String {
        switch self {
        case .heading: "Heading"
        case .text: "Text"
        case .image: "Image"
        case .embed: "Web embed"
        case .slide: "Slide"
        case .box: "Group"
        }
    }
}
