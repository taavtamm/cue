import SwiftUI

/// One setting: a title, an optional line of explanation, and its control
/// on the trailing side.
public struct SettingsRow<Accessory: View>: View {
    let title: String
    let detail: String?
    let accessory: Accessory

    public init(_ title: String, detail: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.detail = detail
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(CueTheme.text)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(CueTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    SettingsGroup("Presenting", footnote: "Applies to every deck.") {
        SettingsRow("Hide the cursor after", detail: "Seconds without moving the mouse") {
            InspectorField("Seconds", value: "2", placement: .leading).frame(width: 90)
        }
        SettingsDivider()
        SettingsRow("Keep the display awake") { Toggle("", isOn: .constant(true)).toggleStyle(.cue) }
    }
    .frame(width: 520)
    .padding(24)
    .background(CueTheme.ground)
    .foregroundStyle(CueTheme.text)
}
