import SwiftUI

/// The round Play button at the centre of the editor toolbar: a white
/// circle with a dark play glyph and the Siri glow behind it.
public struct PlayButton: View {
    var diameter: CGFloat = 42
    let action: () -> Void

    public init(diameter: CGFloat = 42, action: @escaping () -> Void) {
        self.diameter = diameter
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "play.fill")
                .font(.system(size: diameter * 0.4, weight: .semibold))
                .foregroundStyle(Color(hex: 0x0A0A0C))
                .offset(x: diameter * 0.04)
                .frame(width: diameter, height: diameter)
                .background(CueTheme.text, in: Circle())
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .siriGlow(Circle().inset(by: -3), haloBlur: 9, haloOpacity: 0.7, showsRing: false)
        .help("Play (⌥⌘P)")
        .accessibilityLabel("Play slideshow")
    }
}

#Preview {
    PlayButton {}.padding(40).background(CueTheme.ground)
}
