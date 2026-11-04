import CueCore
import Foundation
import WebKit

/// Serves `cue-deck://deck/...` from the deck's folder and nowhere else.
/// The main document comes from memory (see `ServedDocument`).
@MainActor
final class DeckSchemeHandler: NSObject, WKURLSchemeHandler {
    nonisolated static let scheme = "cue-deck"
    nonisolated static let host = "deck"

    private let source: DeckSource

    init(source: DeckSource) {
        self.source = source
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url else { return fail(task, status: 400) }
        guard url.host == Self.host else { return fail(task, status: 403) }

        switch source.folder.resolve(urlPath: url.path(percentEncoded: true)) {
        case .failure:
            fail(task, status: 403)
        case .success(let file) where file == source.folder.root.appending(path: source.fileURL.lastPathComponent):
            let html = ServedDocument.html(source: source.sourceText, structure: source.structure)
            respond(task, url: url, data: Data(html.utf8), mime: "text/html")
        case .success(let file):
            guard let data = try? Data(contentsOf: file) else { return fail(task, status: 404) }
            respond(task, url: url, data: data, mime: MIMEType.forFile(file))
        }
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {
        // Responses are delivered synchronously in `start`, so there is nothing to cancel.
    }

    private func respond(_ task: any WKURLSchemeTask, url: URL, data: Data, mime: String) {
        let contentType = MIMEType.isText(mime) ? "\(mime); charset=utf-8" : mime
        let headers = [
            "Content-Type": contentType,
            "Content-Length": String(data.count),
            "Cache-Control": "no-store",
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    private func fail(_ task: any WKURLSchemeTask, status: Int) {
        let url = task.request.url ?? URL(string: "\(Self.scheme)://\(Self.host)/")!
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])!
        task.didReceive(response)
        task.didFinish()
    }
}
