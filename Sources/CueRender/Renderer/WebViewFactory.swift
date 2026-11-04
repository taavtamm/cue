import AppKit
import CueCore
import WebKit

/// Builds a locked-down WKWebView for one surface: deck folder via the
/// scheme handler, network blocked by content rules, CueBridge in its own
/// world, no persistent storage.
@MainActor
enum WebViewFactory {
    static func make(
        source: DeckSource,
        surface: SurfaceKind,
        rules: WKContentRuleList,
        messages: BridgeMessageHandler,
        policy: SandboxPolicy,
        deckScriptsEnabled: Bool = true
    ) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Off only after a deck's scripts hung the page. Cue's own scripts
        // (bridge, guard) are user scripts and keep running.
        configuration.defaultWebpagePreferences.allowsContentJavaScript = deckScriptsEnabled
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(DeckSchemeHandler(source: source), forURLScheme: DeckSchemeHandler.scheme)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.isElementFullscreenEnabled = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = true

        let content = configuration.userContentController
        let world = BridgeScript.world
        content.add(rules)
        content.addUserScript(PageGuardScript.userScript)
        content.add(messages, contentWorld: world, name: CueBridge.handlerName)
        content.addUserScript(BridgeScript.userScript(in: world))
        content.addUserScript(configureScript(source: source, surface: surface, world: world))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = policy
        webView.uiDelegate = policy
        webView.underPageBackgroundColor = .black
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        #if DEBUG
        webView.isInspectable = true
        #endif
        return webView
    }

    /// Configures the player as soon as the bridge loads, so the first frame
    /// the user sees is already one slide, scaled.
    private static func configureScript(
        source: DeckSource,
        surface: SurfaceKind,
        world: WKContentWorld
    ) -> WKUserScript {
        let config = PlayerConfig(structure: source.structure, surface: surface)
        let js = "window.__cue.receive(\(JSONText.string(BridgeCommand.configure(config).wireMessage)));"
        return WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world)
    }
}
