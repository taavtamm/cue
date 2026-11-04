import CueCore
import Foundation
import WebKit

/// Refuses everything a deck could do to escape its page: new windows,
/// navigating away, downloads, camera, microphone and location (unless the
/// user allowed them for this deck), and modal dialogs that would freeze a show.
@MainActor
final class SandboxPolicy: NSObject, WKNavigationDelegate, WKUIDelegate {
    /// Called when the page's content process dies, so the renderer can reload.
    var onContentProcessTerminated: (() -> Void)?
    var onDidFinishLoad: (() -> Void)?
    var onRefusal: ((SandboxRefusal) -> Void)?
    /// Set by the renderer before each load.
    var rules: SandboxRules?

    // MARK: Navigation

    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        guard let url = action.request.url, let rules else { return (.cancel, preferences) }
        let isMainFrame = action.targetFrame?.isMainFrame ?? true
        if action.shouldPerformDownload {
            onRefusal?(.download(url: url.absoluteString))
            return (.cancel, preferences)
        }
        let allowed = isMainFrame ? rules.allowsMainFrame(url) : rules.allowsSubframe(url)
        if !allowed { onRefusal?(.navigation(url: url.absoluteString, mainFrame: isMainFrame)) }
        return (allowed ? .allow : .cancel, preferences)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor response: WKNavigationResponse
    ) async -> WKNavigationResponsePolicy {
        guard response.canShowMIMEType else {
            onRefusal?(.download(url: response.response.url?.absoluteString ?? ""))
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onDidFinishLoad?()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onContentProcessTerminated?()
    }

    // MARK: Windows and permissions

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for action: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        onRefusal?(.newWindow(url: action.request.url?.absoluteString ?? ""))
        return nil
    }

    func webView(
        _ webView: WKWebView,
        decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo,
        type: WKMediaCaptureType
    ) async -> WKPermissionDecision {
        let permissions = rules?.permissions ?? .none
        let granted = switch type {
        case .camera: permissions.camera
        case .microphone: permissions.microphone
        case .cameraAndMicrophone: permissions.camera && permissions.microphone
        @unknown default: false
        }
        if !granted { onRefusal?(.permission("media capture")) }
        return granted ? .grant : .deny
    }

    func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo
    ) async -> WKPermissionDecision {
        let granted = rules?.permissions.location ?? false
        if !granted { onRefusal?(.permission("location")) }
        return granted ? .grant : .deny
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
        onRefusal?(.permission("file picker"))
        return nil
    }

    // MARK: Dialogs: answered at once so a deck can never block the show.

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
