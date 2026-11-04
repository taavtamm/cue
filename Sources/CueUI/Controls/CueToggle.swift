import SwiftUI

/// The green on/off switch from the designs (38 × 22 pt).
///
///     Toggle("Keep live embeds in sync", isOn: $sync).toggleStyle(.cue)
public struct CueToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.label
                .font(.system(size: 13))
                .foregroundStyle(CueTheme.text)
            Spacer(minLength: 8)
            Button {
                configuration.isOn.toggle()
            } label: {
                Capsule()
                    .fill(configuration.isOn ? CueTheme.success : Color.white.opacity(0.18))
                    .frame(width: 38, height: 22)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).frame(width: 18, height: 18).padding(2)
                            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                    }
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

extension ToggleStyle where Self == CueToggleStyle {
    public static var cue: CueToggleStyle { CueToggleStyle() }
}

#Preview {
    @Previewable @State var a = true
    @Previewable @State var b = false
    VStack {
        Toggle("Render HTML at native resolution", isOn: $a)
        Toggle("Restart animations on enter", isOn: $b)
    }
    .toggleStyle(.cue)
    .frame(width: 320)
    .padding(24)
    .background(CueTheme.ground)
}
