import Foundation

/// Reads a parsed deck and lists every network host it names, before any
/// of its code runs. CueBridge adds what scripts load later (`.runtime`).
public enum RemoteResourceScanner {
    public static func scan(root: HTMLNode, source: String) -> [RemoteResource] {
        var found: [RemoteResource] = []
        let text = source as NSString
        for node in root.descendants {
            found += markupResources(of: node)
            if let style = node["style"] { found += CSSURLScanner.resources(in: style) }
            if node.tag == "style", let range = node.range, range.end <= text.length {
                let css = text.substring(with: NSRange(location: range.start, length: range.length))
                found += CSSURLScanner.resources(in: css)
            }
            if node.tag == "meta", node["http-equiv"]?.lowercased() == "content-security-policy",
               let policy = node["content"] {
                found += ContentSecurityPolicyHosts.resources(inPolicy: policy)
            }
        }
        return unique(found)
    }

    /// Keeps the first of each host+kind, preferring evidence of use over
    /// a mere policy mention.
    static func unique(_ resources: [RemoteResource]) -> [RemoteResource] {
        var best: [String: RemoteResource] = [:]
        var order: [String] = []
        for resource in resources {
            let key = resource.host + "|" + resource.kind.rawValue
            if let existing = best[key] {
                if !existing.origin.isEvidenceOfUse, resource.origin.isEvidenceOfUse { best[key] = resource }
            } else {
                best[key] = resource
                order.append(key)
            }
        }
        return order.compactMap { best[$0] }
    }

    private static func markupResources(of node: HTMLNode) -> [RemoteResource] {
        var urls: [String] = []
        for name in ["src", "href", "data", "poster", "action", "ping", "background"] {
            if let value = node[name] { urls.append(value) }
        }
        for name in ["srcset", "imagesrcset"] {
            if let value = node[name] { urls += candidates(inSrcset: value) }
        }
        if node.tag == "meta", node["http-equiv"]?.lowercased() == "refresh", let content = node["content"],
           let url = content.split(separator: "=", maxSplits: 1).last {
            urls.append(String(url))
        }
        if node.tag == "a" { urls.removeAll { node["href"] == $0 } } // Links don't load until clicked.
        return urls.compactMap { url in
            RemoteResource.host(ofURL: url).map {
                RemoteResource(host: $0, kind: kind(of: node, host: $0), origin: .markup)
            }
        }
    }

    private static func candidates(inSrcset srcset: String) -> [String] {
        srcset.split(separator: ",").compactMap { $0.split(whereSeparator: \.isWhitespace).first.map(String.init) }
    }

    private static func kind(of node: HTMLNode, host: String) -> RemoteResourceKind {
        if FontHosts.isFontHost(host) { return .fonts }
        switch node.tag {
        case "script": return .scripts
        case "img", "picture": return .images
        case "source": return node["type"]?.hasPrefix("image") == true || node["srcset"] != nil ? .images : .media
        case "video", "audio", "track": return .media
        case "iframe", "frame", "object", "embed": return .frames
        case "link": return kind(ofLink: node)
        default: return .other
        }
    }

    private static func kind(ofLink node: HTMLNode) -> RemoteResourceKind {
        let rel = (node["rel"] ?? "").lowercased()
        if rel.contains("stylesheet") { return .styles }
        if rel.contains("icon") { return .images }
        switch (node["as"] ?? "").lowercased() {
        case "font": return .fonts
        case "style": return .styles
        case "script": return .scripts
        case "image": return .images
        default: return .other
        }
    }
}
