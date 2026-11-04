import CueCore
import Testing
@testable import CueRender

@Suite("Bridge wire format")
struct BridgeWireTests {
    @Test func showCommandIsAPlainObject() {
        let message = BridgeCommand.show(ShowPosition(slide: 3, build: 1), finished: true).wireMessage
        #expect(message["type"] as? String == "show")
        #expect(message["finished"] as? Bool == true)
        let position = message["position"] as? [String: Any]
        #expect(position?["slide"] as? Int == 3)
        #expect(position?["build"] as? Int == 1)
    }

    @Test func eventsDecodeFromPlainObjects() {
        #expect(BridgeEvent(wire: ["type": "ready", "slideCount": 12]) == .ready(slideCount: 12))
        let position = BridgeEvent(wire: ["type": "position", "slide": 2, "build": 1])
        #expect(position == .position(ShowPosition(slide: 2, build: 1)))
        #expect(BridgeEvent(wire: ["type": "liveContent", "slides": [1, 2]]) == .liveContent(slides: [1, 2]))
        #expect(BridgeEvent(wire: ["type": "nonsense"]) == nil)
        #expect(BridgeEvent(wire: "not an object") == nil)
    }

    @Test func bridgeScriptJoinsEveryFileInOrder() {
        let source = BridgeScript.source
        let core = source.range(of: "00-core.js")
        let main = source.range(of: "90-main.js")
        #expect(core != nil && main != nil && core!.lowerBound < main!.lowerBound)
        #expect(source.hasPrefix("(function () {"))
    }
}
