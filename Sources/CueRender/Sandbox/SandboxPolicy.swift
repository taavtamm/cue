import Foundation
import WebKit

/// Refuses everything a deck could do to escape its page: new windows,
/// navigating away, downloads, camera/microphone, and modal dialogs that
/// would freeze a show.
@MainActor
final class SandboxPolicy: NSObject, WKNavigationDelegate, WKUIDelegate {
    /// Called when the page's content process dies, so the renderer can reload.
    var onContentProcessTerminated: (() -> Void)?
    var onDidFinishLoad: (() -> Void)?

    private static let allowedSchemes: Set<String> = [DeckSchemeHandler.scheme, "about", "data", "blob"]

    // MARK: Navigation

    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        let scheme = action.request.url?.scheme?.lowercased() ?? ""
        let allowed = Self.allowedSchemes.contains(scheme) && !action.shouldPerformDownload
        return (allowed ? .allow : .cancel, preferences)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor response: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        response.canShowMIMEType ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onDidFinishLoad?()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onContentProcessTerminated?()
    }

    // MARK: UI

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for action: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        nil
    }

    func webView(
        _ webView: WKWebView,
        decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo,
        type: WKMediaCaptureType
    ) async -> WKPermissionDecision {
        .deny
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {}

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        false
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
        nil
    }
}
