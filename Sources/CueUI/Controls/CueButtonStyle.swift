import SwiftUI

/// The rounded buttons used across Cue's chrome.
///
///     Button("Pause timer") {}.buttonStyle(.cue(.glass))
///     Button("Next build") {}.buttonStyle(.cue(.primary))
///     Button("End show") {}.buttonStyle(.cue(.destructive))
public struct CueButtonStyle: ButtonStyle {
    public enum Kind: Sendable {
        /// Translucent white on glass. The default.
        case glass
        /// Solid near-white with dark text, for the main action.
        case primary
        /// Red-tinted, for ending or deleting.
        case destructive
    }

    let kind: Kind
    var height: CGFloat = 36

    public func makeBody(configuration: Configuration) -> some View {
        CueButtonBody(configuration: configuration, kind: kind, height: height)
    }
}

private struct CueButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: CueButtonStyle.Kind
    let height: CGFloat
    @State private var hovering = false

    var body: some View {
        configuration.label
            .font(.system(size: 12.5, weight: kind == .glass ? .regular : .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(background, in: RoundedRectangle(cornerRadius: CueTheme.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .onHover { hovering = $0 }
            .contentShape(Rectangle())
    }

    private var foreground: Color {
        switch kind {
        case .glass: CueTheme.text
        case .primary: Color(hex: 0x0A0A0C)
        case .destructive: CueTheme.destructiveText
        }
    }

    private var background: Color {
        switch kind {
        case .glass: hovering ? CueTheme.controlFillHover : Color.white.opacity(0.08)
        case .primary: CueTheme.text.opacity(hovering ? 0.92 : 1)
        case .destructive: CueTheme.destructive.opacity(hovering ? 0.26 : 0.18)
        }
    }
}

extension ButtonStyle where Self == CueButtonStyle {
    public static func cue(_ kind: CueButtonStyle.Kind = .glass, height: CGFloat = 36) -> CueButtonStyle {
        CueButtonStyle(kind: kind, height: height)
    }
}

#Preview {
    HStack {
        Button("Black screen") {}.buttonStyle(.cue())
        Button("Next build") {}.buttonStyle(.cue(.primary))
        Button("End show") {}.buttonStyle(.cue(.destructive))
    }
    .padding(24)
    .background(CueTheme.ground)
}
