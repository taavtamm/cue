import CueCore
import Foundation

// Plain-object wire format shared with Resources/JS/bridge/00-core.js:
//   Swift → JS  { type: "show", position: { slide, build }, finished }
//   JS → Swift  { type: "ready", slideCount }

extension BridgeCommand {
    var wireMessage: [String: Any] {
        switch self {
        case .configure(let config):
            return ["type": "configure", "config": Self.object(config)]
        case .show(let position, let finished):
            return ["type": "show", "position": Self.object(position), "finished": finished]
        case .setBlack(let on):
            return ["type": "setBlack", "value": on]
        case .setWhite(let on):
            return ["type": "setWhite", "value": on]
        case .setPaused(let on):
            return ["type": "setPaused", "value": on]
        case .alignAnimations(let clock):
            return ["type": "alignAnimations", "clock": Self.object(clock)]
        }
    }

    private static func object(_ value: some Encodable) -> Any {
        let data = (try? JSONEncoder().encode(value)) ?? Data("{}".utf8)
        return (try? JSONSerialization.jsonObject(with: data)) ?? [:]
    }
}

extension BridgeEvent {
    init?(wire body: Any) {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return nil }
        switch type {
        case "ready":
            self = .ready(slideCount: message["slideCount"] as? Int ?? 0)
        case "position":
            let slide = message["slide"] as? Int ?? 0
            let build = message["build"] as? Int ?? 0
            self = .position(ShowPosition(slide: slide, build: build))
        case "liveContent":
            self = .liveContent(slides: message["slides"] as? [Int] ?? [])
        case "error":
            self = .error(message: message["message"] as? String ?? "Unknown bridge error")
        default:
            return nil
        }
    }
}
