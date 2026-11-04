import Foundation

/// Hosts named in a deck's own `<meta http-equiv="Content-Security-Policy">`.
/// They say what the deck is allowed to load, not what it does load.
enum ContentSecurityPolicyHosts {
    static func resources(inPolicy policy: String) -> [RemoteResource] {
        var found: [RemoteResource] = []
        for directive in policy.split(separator: ";") {
            let parts = directive.split(whereSeparator: \.isWhitespace).map(String.init)
            guard let name = parts.first?.lowercased() else { continue }
            let kind = kind(forDirective: name)
            for source in parts.dropFirst() {
                guard let host = host(ofSource: source) else { continue }
                found.append(RemoteResource(host: host, kind: kind, origin: .policy))
            }
        }
        return found
    }

    /// `https://fonts.gstatic.com`, `fonts.gstatic.com`, `*.example.com:443`.
    /// Keywords ('self', data:, 'unsafe-inline') aren't hosts.
    private static func host(ofSource source: String) -> String? {
        if source.hasPrefix("'") || source.hasSuffix(":") { return nil }
        if let host = RemoteResource.host(ofURL: source) { return host }
        let bare = source.split(separator: "/").first.map(String.init) ?? source
        let withoutPort = bare.split(separator: ":").first.map(String.init) ?? bare
        guard withoutPort.contains("."), !withoutPort.hasPrefix("*") else { return nil }
        return withoutPort.lowercased()
    }

    private static func kind(forDirective name: String) -> RemoteResourceKind {
        switch name {
        case "font-src": .fonts
        case "style-src", "style-src-elem": .styles
        case "script-src", "script-src-elem": .scripts
        case "img-src": .images
        case "media-src": .media
        case "frame-src", "child-src": .frames
        case "connect-src": .data
        default: .other
        }
    }
}
