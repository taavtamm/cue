/// The Settings window's sections, in sidebar order.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, presenting, editor, privacy, claude

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .presenting: "Presenting"
        case .editor: "Editor"
        case .privacy: "Privacy & Network"
        case .claude: "Claude"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .presenting: "play.rectangle"
        case .editor: "pencil.and.outline"
        case .privacy: "hand.raised"
        case .claude: "sparkles"
        }
    }
}
