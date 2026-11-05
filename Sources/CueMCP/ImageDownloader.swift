import Foundation

/// Fetches an image Claude asks Cue to add from the web. Cue does this, not
/// the deck: deck pages never reach the network unless the user allows it.
/// HTTPS only (plain http only to this Mac, for tests), at most 20 MB, and
/// it must really be an image.
public struct ImageDownloader: Sendable {
    public static let maximumBytes = 20 * 1024 * 1024
    let session: URLSession
    let allowsLoopbackHTTP: Bool

    public init(session: URLSession = .shared, allowsLoopbackHTTP: Bool = false) {
        self.session = session
        self.allowsLoopbackHTTP = allowsLoopbackHTTP
    }

    public func fetch(_ url: URL) async throws -> Data {
        let loopback = ["localhost", "127.0.0.1", "::1"].contains(url.host ?? "")
        guard url.scheme == "https" || (allowsLoopbackHTTP && loopback && url.scheme == "http") else {
            throw CueMCPError.invalid("Cue only downloads images over https://.")
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let data: Data, response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch {
            throw CueMCPError.invalid("Couldn't download \(url.absoluteString): \(error.localizedDescription)")
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CueMCPError.invalid("Downloading \(url.absoluteString) failed: HTTP \(http.statusCode).")
        }
        guard data.count <= Self.maximumBytes else {
            throw CueMCPError.invalid("That image is \(data.count / 1_048_576) MB; Cue downloads images up to 20 MB.")
        }
        let type = (response.mimeType ?? "").lowercased()
        guard type.hasPrefix("image/") || ImageSniffer.isImage(data) else {
            throw CueMCPError.invalid("\(url.absoluteString) isn't an image (it's \(type.isEmpty ? "unknown" : type)).")
        }
        return data
    }
}

/// Recognises image files by their first bytes.
enum ImageSniffer {
    static func mime(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(16))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "image/png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: Array("GIF8".utf8)) { return "image/gif" }
        if bytes.count >= 12, bytes[0..<4] == [0x52, 0x49, 0x46, 0x46], bytes[8..<12] == [0x57, 0x45, 0x42, 0x50] { return "image/webp" }
        if let text = String(data: data.prefix(512), encoding: .utf8), text.contains("<svg") { return "image/svg+xml" }
        return nil
    }

    static func isImage(_ data: Data) -> Bool { mime(data) != nil }
}
