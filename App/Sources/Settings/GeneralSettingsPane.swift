import AppKit
import CueCore
import CueUI
import SwiftUI

/// Where new decks go, and the recent-decks list.
struct GeneralSettingsPane: View {
    @Bindable var settings: CueSettings
    @State private var recentCount = NSDocumentController.shared.recentDocumentURLs.count

    var body: some View {
        SettingsGroup("New presentations") {
            SettingsRow("Save new presentations in", detail: folderText) {
                HStack(spacing: 8) {
                    if settings.defaultSaveFolder != nil {
                        Button("Use Default") { settings.defaultSaveFolder = nil }.buttonStyle(.cue(height: 30))
                    }
                    Button("Choose…", action: chooseFolder).buttonStyle(.cue(height: 30))
                }
            }
        }
        SettingsGroup("Recent decks", footnote: "Shown on the Welcome window and in File › Open Recent.") {
            SettingsRow("\(recentCount) recent deck\(recentCount == 1 ? "" : "s")") {
                Button("Clear Recent Decks") {
                    NSDocumentController.shared.clearRecentDocuments(nil)
                    recentCount = 0
                }
                .buttonStyle(.cue(.destructive, height: 30))
                .disabled(recentCount == 0)
            }
        }
    }

    private var folderText: String {
        guard let folder = settings.defaultSaveFolder else { return "Wherever you last saved" }
        return (folder.path as NSString).abbreviatingWithTildeInPath
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = settings.defaultSaveFolder
        panel.begin { response in
            if response == .OK, let url = panel.url { settings.defaultSaveFolder = url }
        }
    }
}
