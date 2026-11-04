import SwiftUI

/// The green switch on its own, for the trailing side of a `SettingsRow`
/// (whose title already names it). The title is kept for VoiceOver.
public struct SettingsSwitch: View {
    let title: String
    @Binding var isOn: Bool

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) { EmptyView() }
            .toggleStyle(.cue)
            .fixedSize()
            .accessibilityLabel(title)
    }
}
