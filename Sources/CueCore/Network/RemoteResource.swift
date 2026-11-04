import Foundation

/// Something a deck wants from the network: which host, what for, and how
/// Cue found out. Cue blocks all of it until the user allows the host.
public struct RemoteResource: Sendable, Equatable, Hashable, Codable {
    /// Lowercased host, e.g. "fonts.gstatic.com".
    public var host: String
    public var kind: RemoteResourceKind
    public var origin: RemoteResourceOrigin

    public init(host: String, kind: RemoteResourceKind, origin: RemoteResourceOrigin) {
        self.host = host.lowercased()
        self.kind = kind
        self.origin = origin
    }

    /// The host of an http(s) or ws(s) URL, or nil for anything local.
    public static func host(ofURL text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let isProtocolRelative = lower.hasPrefix("//")
        let isRemote = ["http://", "https://", "ws://", "wss://"].contains { lower.hasPrefix($0) }
        guard isRemote || isProtocolRelative else { return nil }
        let absolute = isProtocolRelative ? "https:" + trimmed : trimmed
        guard let host = URLComponents(string: absolute)?.host, !host.isEmpty else { return nil }
        return host.lowercased()
    }
}

public enum RemoteResourceKind: String, Sendable, Codable, CaseIterable, Comparable {
    case fonts, styles, scripts, images, media, frames, data, other

    /// The plural noun used in "This deck loads fonts from …".
    public var noun: String {
        switch self {
        case .fonts: "fonts"
        case .styles: "styles"
        case .scripts: "scripts"
        case .images: "images"
        case .media: "video and audio"
        case .frames: "web pages"
        case .data: "data"
        case .other: "content"
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

public enum RemoteResourceOrigin: String, Sendable, Codable {
    /// Named in an element's src/href/srcset.
    case markup
    /// Named in CSS: url(), @import, @font-face.
    case stylesheet
    /// Only listed in the deck's own Content-Security-Policy. The deck may
    /// never use it, so Cue doesn't ask about these on their own.
    case policy
    /// Reported by CueBridge while the page ran (e.g. a script added it).
    case runtime

    /// True when this is evidence the deck actually loads from the host.
    public var isEvidenceOfUse: Bool { self != .policy }
}
