import Foundation
import WebKit

/// A small script that runs in the deck's own world before any deck code and
/// removes APIs the content rules can't police (WebRTC connects over UDP,
/// outside WebKit's loader). Best effort: see Resources/JS/guard/page-guard.js.
enum PageGuardScript {
    static let source: String = {
        guard let url = Bundle.module.url(forResource: "page-guard", withExtension: "js", subdirectory: "JS/guard"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { fatalError("page-guard.js is missing from the CueRender bundle") }
        return text
    }()

    @MainActor static var userScript: WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false, in: .page)
    }
}
