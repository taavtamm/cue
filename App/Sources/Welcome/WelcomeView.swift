import CueCore
import CueUI
import SwiftUI
import UniformTypeIdentifiers

/// The Welcome window: start a new presentation, open one, or pick up a
/// recent deck. Any supported file can be dropped anywhere on it.
struct WelcomeView: View {
    let model: WelcomeModel
    let actions: WelcomeActions
    @State private var dropTargeted = false
    @Environment(\.isSnapshotRendering) private var isSnapshot

    var body: some View {
        HStack(spacing: 0) {
            start.frame(width: 300)
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1).padding(.vertical, 24)
            recentDecks.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(CueTheme.text)
        .overlay { if dropTargeted { dropHighlight } }
        .modifier(DeckDropTarget(isEnabled: !isSnapshot, isTargeted: $dropTargeted) { drop($0) })
    }

    private var start: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 24)
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text("Cue").font(.system(size: 30, weight: .bold)).tracking(-0.5)
            Text("Present and edit HTML decks").font(.system(size: 13)).foregroundStyle(CueTheme.textSecondary)
            Spacer().frame(height: 12)
            Button(action: actions.newPresentation) {
                Label("New Presentation", systemImage: "plus").frame(width: 200)
            }
            .buttonStyle(.cue(.primary, height: 40))
            .keyboardShortcut("n")
            Button(action: actions.open) { Label("Open…", systemImage: "folder").frame(width: 200) }
                .buttonStyle(.cue(.glass, height: 40))
                .keyboardShortcut("o")
            Text("or drop a presentation here\nHTML, PowerPoint, Keynote, PDF")
                .font(.system(size: 11.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(CueTheme.textTertiary)
            Spacer(minLength: 24)
        }
        .padding(.horizontal, 24)
    }

    private var recentDecks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Recent").padding(.leading, 4)
            if model.recents.isEmpty {
                Text("Decks you open will appear here.")
                    .font(.system(size: 13))
                    .foregroundStyle(CueTheme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SnapshotFriendlyScrollView(axis: .vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 240), spacing: 12)], spacing: 12) {
                        ForEach(model.recents, id: \.self) { deck in
                            RecentDeckCell(
                                name: deck.deletingPathExtension().lastPathComponent,
                                location: Self.folderName(of: deck),
                                image: model.thumbnails.images[deck]
                            ) { actions.openURL(deck) }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .padding(EdgeInsets(top: NSWindow.cueToolbarHeight, leading: 20, bottom: 0, trailing: 20))
    }

    private static func folderName(of deck: URL) -> String {
        (deck.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(CueTheme.selection, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            .background(CueTheme.selection.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(10)
            .allowsHitTesting(false)
    }

    /// Opens every dropped file Cue can read; the import path handles the rest.
    private func drop(_ providers: [NSItemProvider]) -> Bool {
        let readable = Set(PresentationTypes.extensions)
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, readable.contains(url.pathExtension.lowercased()) else { return }
                Task { @MainActor in actions.openURL(url) }
            }
        }
        return accepted
    }
}

/// What the Welcome window's buttons do. Set by the app delegate.
struct WelcomeActions {
    var newPresentation: () -> Void = {}
    var open: () -> Void = {}
    var openURL: (URL) -> Void = { _ in }
}
