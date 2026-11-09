import AppKit
import CueCore
import CueUI
import SwiftUI

/// What each recent deck may load from the network or ask the Mac for.
/// Choices are made per deck in the deck window; this is where to undo them.
struct PrivacySettingsPane: View {
    @State private var entries: [DeckPrivacyEntry] = []
    @State private var failure: String?

    var body: some View {
        Text("Decks are offline and can't use the camera, microphone or location unless you allow it for that deck.")
            .font(.system(size: 12.5))
            .foregroundStyle(CueTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        if let failure { Banner(systemImage: "exclamationmark.triangle", message: failure, actions: []) }
        if entries.isEmpty {
            SettingsGroup {
                SettingsRow("No deck has network or device access", detail: "Recent decks are all offline.") {
                    EmptyView()
                }
            }
        }
        ForEach($entries) { $entry in
            SettingsGroup(entry.name, footnote: footnote) {
                hosts(for: $entry)
                devices(for: $entry)
            }
        }
        Color.clear.frame(height: 0)
            .onAppear {
                entries = DeckPrivacyEntry.load(for: RecentDecks.pruned(NSDocumentController.shared.recentDocumentURLs))
            }
    }

    private let footnote = "Camera and microphone also need Cue to be allowed in System Settings › Privacy & Security."

    @ViewBuilder private func hosts(for entry: Binding<DeckPrivacyEntry>) -> some View {
        ForEach(entry.wrappedValue.grants.allowedHosts, id: \.self) { host in
            SettingsRow(host, detail: "Allowed") {
                Button("Revoke") { change(entry) { $0.allowedHosts.removeAll { $0 == host } } }
                    .buttonStyle(.cue(.destructive, height: 28))
            }
            SettingsDivider()
        }
        ForEach(entry.wrappedValue.grants.deniedHosts, id: \.self) { host in
            SettingsRow(host, detail: "Refused, Cue won't ask again") {
                Button("Ask Again") { change(entry) { $0.deniedHosts.removeAll { $0 == host } } }
                    .buttonStyle(.cue(height: 28))
            }
            SettingsDivider()
        }
    }

    @ViewBuilder private func devices(for entry: Binding<DeckPrivacyEntry>) -> some View {
        let permissions = entry.wrappedValue.grants.permissions
        toggle("Camera", permissions.camera, entry) { $0.camera = $1 }
        SettingsDivider()
        toggle("Microphone", permissions.microphone, entry) { $0.microphone = $1 }
        SettingsDivider()
        toggle("Location", permissions.location, entry) { $0.location = $1 }
    }

    private func toggle(
        _ title: String, _ isOn: Bool, _ entry: Binding<DeckPrivacyEntry>,
        set: @escaping (inout DeckPermissions, Bool) -> Void
    ) -> some View {
        SettingsRow(title) {
            SettingsSwitch(title, isOn: Binding(
                get: { isOn },
                set: { value in change(entry) { set(&$0.permissions, value) } }
            ))
        }
    }

    private func change(_ entry: Binding<DeckPrivacyEntry>, _ edit: (inout DeckGrants) -> Void) {
        do {
            try entry.wrappedValue.update(edit)
            failure = nil
        } catch {
            failure = "Couldn't save “\(entry.wrappedValue.name)”: \(error.localizedDescription)"
        }
    }
}
