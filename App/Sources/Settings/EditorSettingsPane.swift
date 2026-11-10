import AppKit
import CueCore
import CueUI
import SwiftUI

/// Defaults for new text, and how inserted images are stored.
struct EditorSettingsPane: View {
    @Bindable var settings: CueSettings
    @Environment(\.isSnapshotRendering) private var isSnapshot

    var body: some View {
        SettingsGroup("New text", footnote: "Used for new presentations and new text boxes.") {
            SettingsRow("Font") {
                if isSnapshot { fontLabel.modifier(FieldChrome()) } else { fontMenu } // ImageRenderer can't draw menus.
            }
            SettingsDivider()
            SettingsRow("Size", detail: "Points on a 1920 × 1080 slide") {
                InspectorField("pt", value: settings.defaultFontSize.formatted(), placement: .leading) {
                    if let size = Double($0) { settings.defaultFontSize = size }
                }
                .frame(width: 96)
            }
        }
        SettingsGroup("Live content", footnote: "Animated slides keep the GPU busy. Paused slides resume when you "
                      + "come back to Cue, and play while Claude is editing.") {
            SettingsSwitch("Pause live slides while Cue is in the background",
                           isOn: $settings.pausesLiveContentInBackground)
        }
        SettingsGroup("Images", footnote: "The deck stays one HTML file you can send or open in any browser.") {
            SettingsRow("Inserted images", detail: "Stored inside the deck as data, not in a separate folder") {
                Pill("Embedded in the HTML file", .status(dot: CueTheme.success))
            }
        }
    }

    private var fontMenu: some View {
        Menu {
            Button(CueSettings.systemFont) { settings.defaultFontFamily = CueSettings.systemFont }
            Divider()
            ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                Button(family) { settings.defaultFontFamily = family }
            }
        } label: {
            fontLabel
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .modifier(FieldChrome())
    }

    private var fontLabel: some View {
        Text(settings.defaultFontFamily).font(.system(size: 12.5)).frame(minWidth: 140, alignment: .leading)
    }
}

/// The rounded field background the inspector uses, around a menu.
private struct FieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
