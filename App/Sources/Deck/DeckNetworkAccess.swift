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
    /// The sidecar couldn't be read, so choices aren't saved (it is never overwritten).
    private(set) var saveError: String?
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
        save { $0.allowedHosts = Array(Set($0.allowedHosts + request.hosts)).sorted() }
        refresh()
        onAllowed?()
    }

    func notNow() {
        postponed.formUnion(request?.hosts ?? [])
        refresh()
    }

    func never() {
        guard let request else { return }
        save { $0.deniedHosts = Array(Set($0.deniedHosts + request.hosts)).sorted() }
        refresh()
    }

    func dismissScriptsNotice() { scriptsStopped = false }

    private func refresh() {
        request = NetworkRequest.pending(
            from: wanted, allowed: sidecar.allowedHosts, denied: sidecar.deniedHosts + postponed
        )
    }

    /// Merges a choice into the sidecar on disk, keeping everything else in it
    /// (display roles, timings, other choices made meanwhile). If the file
    /// can't be read, it is left alone and the choice applies to this session.
    private func save(_ change: (inout CueSidecar) -> Void) {
        change(&sidecar)
        do {
            try CueSidecar.update(at: sidecarURL, change)
            sidecar = try CueSidecar.load(from: sidecarURL)
            saveError = nil
        } catch {
            saveError = "Couldn't save to \(sidecarURL.lastPathComponent): \(error.localizedDescription)"
            NSLog("Cue: %@", saveError ?? "")
        }
    }
}
