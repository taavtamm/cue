import Foundation

/// One piece of an element's content in document order: character data or a
/// child element. Mixed content (`Hello <span>big</span> world`) needs this;
/// `XNode.text` alone loses where the children sat.
public enum XContent: Sendable {
    case text(String)
    case element(XNode)
}
