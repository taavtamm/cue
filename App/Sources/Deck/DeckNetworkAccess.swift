import CueCore
import CueRender
import Foundation
import Observation

/// What this deck may reach on the network, and whether to ask about it.
/// Choices live in Cue's own store (`DeckGrantStore`), never in the HTML or the sidecar.
/// Only the deck window asks; a running show uses what's already allowed.
@MainActor @Observable
final class DeckNetworkAccess {
    /// The question to show, if any.
    private(set) var request: NetworkRequest?
    /// Set when the deck's scripts hung and Cue turned them off.
    private(set) var scriptsStopped = false
    /// The store couldn't be read, so choices aren't saved (it is never overwritten).
    private(set) var saveError: String?
    /// Called after the user allows hosts, so surfaces can reload with them.
    var onAllowed: (() -> Void)?

    private let deckURL: URL
    private let store = DeckGrantStore.standard
    private var grants: DeckGrants
    private var wanted: [RemoteResource] = []
    /// "Not now" lasts until the deck is closed.
    private var postponed: Set<String> = []

    init(document: DeckDocument) {
        deckURL = document.fileURL
        grants = store.grants(forDeck: deckURL)
        note(document.remoteResources)
    }

    var allowedHosts: [String] { grants.allowedHosts }

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
            from: wanted, allowed: grants.allowedHosts, denied: grants.deniedHosts + postponed
        )
    }

    /// Merges a choice into the store, keeping other choices made meanwhile.
    /// If the store can't be read, it is left alone and the choice applies to this session.
    private func save(_ change: (inout DeckGrants) -> Void) {
        change(&grants)
        do {
            grants = try store.update(forDeck: deckURL, change)
            saveError = nil
        } catch {
            saveError = "Couldn't save to \(store.fileURL.lastPathComponent): \(error.localizedDescription)"
            NSLog("Cue: %@", saveError ?? "")
        }
    }
}
