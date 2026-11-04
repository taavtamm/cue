import SwiftUI

/// A titled card of settings rows, as in the Displays window's toggles:
///
///     SettingsGroup("Presenting") {
///         SettingsRow("Hide the cursor after") { … }
///         SettingsDivider()
///         SettingsRow("Keep the display awake") { … }
///     }
public struct SettingsGroup<Content: View>: View {
    let title: String?
    let footnote: String?
    let content: Content

    public init(_ title: String? = nil, footnote: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footnote = footnote
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { SectionLabel(title).padding(.leading, 4) }
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.045), in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.07)))
            if let footnote {
                Text(footnote)
                    .font(.system(size: 11.5))
                    .foregroundStyle(CueTheme.textTertiary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
}

/// The hairline between rows of a `SettingsGroup`.
public struct SettingsDivider: View {
    public init() {}
    public var body: some View { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
}
