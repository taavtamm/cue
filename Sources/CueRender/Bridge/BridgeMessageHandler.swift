import CueCore
import Foundation
import WebKit

/// Receives CueBridge's messages. Registered only in the bridge's content
/// world, so deck scripts have no handler to call.
@MainActor
final class BridgeMessageHandler: NSObject, WKScriptMessageHandler {
    var onEvent: ((BridgeEvent) -> Void)?
    var onSandboxEvent: ((SandboxEvent) -> Void)?
    /// The surface's current page. Messages from a page it replaced (a reload
    /// still in flight, a slow `ready`) are dropped.
    weak var currentWebView: WKWebView?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.world.name == CueBridge.worldName, message.frameInfo.isMainFrame,
              let sender = message.webView, sender === currentWebView
        else { return }
        if let resources = Self.remoteResources(in: message.body) {
            onSandboxEvent?(.remoteResources(resources))
        } else if let event = BridgeEvent(wire: message.body) {
            onEvent?(event)
        }
    }

    /// `{ type: "remoteResources", resources: [{ host, kind }] }` from 75-remote-resources.js.
    static func remoteResources(in body: Any) -> [RemoteResource]? {
        guard let message = body as? [String: Any], message["type"] as? String == "remoteResources",
              let list = message["resources"] as? [[String: Any]]
        else { return nil }
        return list.compactMap { item in
            guard let host = item["host"] as? String else { return nil }
            let kind = RemoteResourceKind(rawValue: item["kind"] as? String ?? "") ?? .other
            return RemoteResource(host: host, kind: kind, origin: .runtime)
        }
    }
}
