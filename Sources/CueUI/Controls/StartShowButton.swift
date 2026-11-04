import SwiftUI

/// The white "Start show" capsule with the Siri glow, used in Displays and
/// the Launcher. Pass a different title for "Present".
public struct StartShowButton: View {
    let title: String
    var height: CGFloat = 42
    let action: () -> Void

    public init(_ title: String = "Start show", height: CGFloat = 42, action: @escaping () -> Void) {
        self.title = title
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0x0A0A0C))
                .padding(.leading, 16)
                .padding(.trailing, 20)
                .frame(height: height)
                .background(CueTheme.text, in: Capsule())
        }
        .buttonStyle(.plain)
        .siriGlow(Capsule().inset(by: -2), haloBlur: 12, haloOpacity: 0.6, showsRing: false)
    }
}

#Preview {
    StartShowButton {}.padding(40).background(CueTheme.ground)
}
