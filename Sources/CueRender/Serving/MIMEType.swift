import Foundation
import UniformTypeIdentifiers

/// Content types for files served from a deck folder.
enum MIMEType {
    static func forFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if let known = overrides[ext] { return known }
        return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    }

    /// Types WebKit is strict about, pinned so the system database can't vary them.
    private static let overrides: [String: String] = [
        "html": "text/html", "htm": "text/html",
        "js": "text/javascript", "mjs": "text/javascript",
        "css": "text/css", "json": "application/json",
        "svg": "image/svg+xml", "wasm": "application/wasm",
        "woff": "font/woff", "woff2": "font/woff2",
    ]

    static func isText(_ mime: String) -> Bool {
        mime.hasPrefix("text/") || mime == "application/json" || mime == "image/svg+xml"
    }
}
