import CueCore
import CueUI
import SwiftUI

/// The Settings window: sections on the left, the chosen one on the right.
struct SettingsView: View {
    @Bindable var settings: CueSettings
    @State var section: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            SnapshotFriendlyScrollView(axis: .vertical) {
                pane
                    .padding(EdgeInsets(top: NSWindow.cueToolbarHeight, leading: 28, bottom: 28, trailing: 28))
                    .frame(maxWidth: 640, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(CueTheme.text)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { item in
                SidebarItem(item.title, systemImage: item.systemImage, isSelected: section == item) { section = item }
            }
            Spacer()
        }
        .padding(EdgeInsets(top: NSWindow.cueToolbarHeight + 4, leading: 12, bottom: 12, trailing: 12))
        .frame(width: 210)
        .background(Color.black.opacity(0.18))
    }

    @ViewBuilder private var pane: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(section.title).font(.system(size: 20, weight: .semibold)).tracking(-0.2)
            switch section {
            case .general: GeneralSettingsPane(settings: settings)
            case .presenting: PresentingSettingsPane(settings: settings)
            case .editor: EditorSettingsPane(settings: settings)
            case .privacy: PrivacySettingsPane()
            case .claude: ClaudeSettingsPane()
            }
        }
    }
}
