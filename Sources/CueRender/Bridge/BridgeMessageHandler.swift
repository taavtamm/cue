import CueCore
import Foundation
import WebKit

/// Receives CueBridge's messages. Registered only in the bridge's content
/// world, so deck scripts have no handler to call.
@MainActor
final class BridgeMessageHandler: NSObject, WKScriptMessageHandler {
    var onEvent: ((BridgeEvent) -> Void)?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.world.name == CueBridge.worldName, message.frameInfo.isMainFrame,
              let event = BridgeEvent(wire: message.body)
        else { return }
        onEvent?(event)
    }
}
