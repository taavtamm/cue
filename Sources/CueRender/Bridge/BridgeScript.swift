import Foundation
import WebKit

/// Loads CueBridge's JavaScript. The sources are small files in
/// Resources/JS/bridge, joined in file-name order (00-core.js first) and
/// wrapped in one function so nothing leaks into the bridge world's globals
/// except `window.__cue`.
enum BridgeScript {
    static let source: String = {
        guard let folder = Bundle.module.url(forResource: "bridge", withExtension: nil, subdirectory: "JS"),
              let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { fatalError("CueBridge JavaScript is missing from the CueRender bundle") }

        let parts = files
            .filter { $0.pathExtension == "js" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { "// --- \($0.lastPathComponent)\n" + ((try? String(contentsOf: $0, encoding: .utf8)) ?? "") }
        return "(function () {\n'use strict';\n" + parts.joined(separator: "\n") + "\n})();"
    }()

    /// The bridge, injected into every page before the deck finishes loading.
    @MainActor static func userScript(in world: WKContentWorld) -> WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world)
    }

    /// Listeners that must be registered before any deck script runs
    /// (Resources/JS/early). They call into the bridge once it has loaded.
    static let earlySource: String = {
        guard let url = Bundle.module.url(forResource: "key-guard", withExtension: "js", subdirectory: "JS/early"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { fatalError("key-guard.js is missing from the CueRender bundle") }
        return text
    }()

    /// The early listeners, in the bridge world at document start.
    @MainActor static func earlyUserScript(in world: WKContentWorld) -> WKUserScript {
        WKUserScript(source: earlySource, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: world)
    }

    @MainActor static var world: WKContentWorld { .world(name: CueBridge.worldName) }
}
