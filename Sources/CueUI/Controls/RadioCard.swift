import SwiftUI

/// One choice in a list of exclusive options, with a colour dot, a title and
/// a line of explanation. Used for display roles.
public struct RadioCard: View {
    let title: String
    let detail: String
    let dot: Color
    let isOn: Bool
    let action: () -> Void
    @State private var hovering = false

    public init(_ title: String, detail: String, dot: Color, isOn: Bool, action: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.dot = dot
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(dot)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(Color.white.opacity(isOn ? 0.9 : 0), lineWidth: 3).padding(-3))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13.5, weight: .semibold))
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Color.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(CueTheme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(border))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }

    private var background: Color {
        if isOn { return CueTheme.selection.opacity(0.16) }
        return Color.white.opacity(hovering ? 0.08 : 0.04)
    }

    private var border: Color { isOn ? CueTheme.selection.opacity(0.55) : Color.white.opacity(0.06) }
}

#Preview {
    VStack(spacing: 6) {
        RadioCard("Stage", detail: "The audience sees the live slide.", dot: CueTheme.destructive, isOn: true) {}
        RadioCard("Off", detail: "Leave this display alone.", dot: .white.opacity(0.35), isOn: false) {}
    }
    .frame(width: 380)
    .padding(24)
    .background(CueTheme.ground)
}
