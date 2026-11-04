import AppKit
import WebKit

/// Notices when a deck's scripts lock up the page (an endless loop blocks
/// the page's only thread, Cue's bridge included). It pings Cue's world
/// every `interval`; after `allowedMisses` unanswered pings it calls `onHang`.
/// Pings only count while the web view is visible, because WebKit may
/// suspend hidden pages and that isn't a hang.
@MainActor
final class ScriptWatchdog {
    var interval: Duration = .seconds(3)
    var allowedMisses = 2

    private var task: Task<Void, Never>?

    func start(_ webView: WKWebView, onHang: @escaping @MainActor () -> Void) {
        stop()
        let interval = interval, allowedMisses = allowedMisses
        task = Task { [weak webView] in
            var misses = 0
            var answered = true
            var outstanding = Probe()
            while !Task.isCancelled, let webView {
                if answered {
                    outstanding = Probe()
                    outstanding.send(to: webView)
                }
                try? await Task.sleep(for: interval)
                answered = outstanding.answered
                misses = answered || !Self.isShown(webView) ? 0 : misses + 1
                if misses >= allowedMisses {
                    onHang()
                    return
                }
            }
        }
    }

    /// On screen and not minimised, with the app not hidden. (Occlusion state
    /// is not used: it stays "hidden" for windows of background processes.)
    private static func isShown(_ webView: WKWebView) -> Bool {
        guard let window = webView.window else { return false }
        return window.isVisible && !window.isMiniaturized && !NSApplication.shared.isHidden
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

/// One ping. Any reply, even an error, means the page's thread is alive.
@MainActor
private final class Probe {
    private(set) var answered = false

    func send(to webView: WKWebView) {
        webView.callAsyncJavaScript("return true", in: nil, in: BridgeScript.world) { [weak self] _ in
            self?.answered = true
        }
    }
}
