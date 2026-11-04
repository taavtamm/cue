import SwiftUI

/// A borderless icon-only button with a hover fill. Always give it a label
/// for VoiceOver; it shows as a tooltip too.
public struct IconButton: View {
    let systemImage: String
    let label: String
    var size: CGFloat = 32
    var iconSize: CGFloat = 15
    let action: () -> Void
    @State private var hovering = false

    public init(_ label: String, systemImage: String, size: CGFloat = 32, iconSize: CGFloat = 15,
                action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.size = size
        self.iconSize = iconSize
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.8))
                .frame(width: size, height: size)
                .background(
                    hovering ? CueTheme.controlFillHover : .clear,
                    in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

#Preview {
    HStack {
        IconButton("Toggle sidebar", systemImage: "sidebar.left") {}
        IconButton("Add slide", systemImage: "plus.rectangle") {}
        IconButton("Dictate", systemImage: "mic", size: 38, iconSize: 18) {}
    }
    .padding(24)
    .background(CueTheme.ground)
}
