import CueUI
import SwiftUI

/// The deck window's sandbox banners: a network question, or a note that
/// the deck's scripts were turned off. Empty (zero height) otherwise.
struct NetworkAccessBanner: View {
    let access: DeckNetworkAccess

    var body: some View {
        VStack(spacing: 8) {
            if let request = access.request {
                Banner(
                    systemImage: "network",
                    message: request.message + " Allow?",
                    detail: "Cue blocks the network for every deck until you allow it. Saved with this deck.",
                    actions: [
                        .init("Allow", kind: .primary) { access.allow() },
                        .init("Not now") { access.notNow() },
                        .init("Never") { access.never() },
                    ]
                )
            }
            if access.scriptsStopped {
                Banner(
                    systemImage: "exclamationmark.triangle",
                    message: "This deck's scripts stopped responding, so Cue turned them off here.",
                    detail: "Slides still show. Scripted animations and embeds are paused until you reopen the deck.",
                    actions: [.init("OK") { access.dismissScriptsNotice() }]
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, access.request == nil && !access.scriptsStopped ? 0 : 8)
        .animation(.easeOut(duration: 0.2), value: access.request)
    }
}
