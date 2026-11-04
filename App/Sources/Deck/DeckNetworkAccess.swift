import CueCore
import CueRender
import Foundation
import Observation

/// What this deck may reach on the network, and whether to ask about it.
/// Choices live in the deck's sidecar (`deck.cue.json`), never in the HTML.
/// Only the deck window asks; a running show uses what's already allowed.
@MainActor @Observable
final class DeckNetworkAccess {
    /// The question to show, if any.
    private(set) var request: NetworkRequest?
    /// Set when the deck's scripts hung and Cue turned them off.
    private(set) var scriptsStopped = false
    /// Called after the user allows hosts, so surfaces can reload with them.
    var onAllowed: (() -> Void)?

    private let sidecarURL: URL
    private var sidecar: CueSidecar
    private var wanted: [RemoteResource] = []
    /// "Not now" lasts until the deck is closed.
    private var postponed: Set<String> = []

    init(document: DeckDocument) {
        sidecarURL = document.sidecarURL
        sidecar = (try? CueSidecar.load(from: sidecarURL)) ?? CueSidecar()
        note(document.remoteResources)
    }

    var allowedHosts: [String] { sidecar.allowedHosts }

    func handle(_ event: SandboxEvent) {
        switch event {
        case .remoteResources(let resources): note(resources)
        case .scriptsStopped: scriptsStopped = true
        case .refused: break
        }
    }

    func note(_ resources: [RemoteResource]) {
        wanted += resources
        refresh()
    }

    func allow() {
        guard let request else { return }
        sidecar.allowedHosts = Array(Set(sidecar.allowedHosts + request.hosts)).sorted()
        save()
        refresh()
        onAllowed?()
    }

    func notNow() {
        postponed.formUnion(request?.hosts ?? [])
        refresh()
    }

    func never() {
        guard let request else { return }
        sidecar.deniedHosts = Array(Set(sidecar.deniedHosts + request.hosts)).sorted()
        save()
        refresh()
    }

    func dismissScriptsNotice() { scriptsStopped = false }

    private func refresh() {
        request = NetworkRequest.pending(
            from: wanted, allowed: sidecar.allowedHosts, denied: sidecar.deniedHosts + postponed
        )
    }

    private func save() {
        // Re-read first so choices made elsewhere (display roles, timings) survive.
        var latest = (try? CueSidecar.load(from: sidecarURL)) ?? CueSidecar()
        latest.allowedHosts = sidecar.allowedHosts
        latest.deniedHosts = sidecar.deniedHosts
        sidecar = latest
        try? latest.save(to: sidecarURL)
    }
}
