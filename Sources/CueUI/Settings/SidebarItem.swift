import SwiftUI

/// A row in a window's source list (the Settings sections): icon and title,
/// highlighted when selected.
public struct SidebarItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    public init(_ title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? CueTheme.text : CueTheme.textSecondary)
                Text(title).font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(CueTheme.text)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var background: Color {
        if isSelected { return CueTheme.controlSelected }
        return hovering ? Color.white.opacity(0.06) : .clear
    }
}

#Preview {
    VStack(spacing: 2) {
        SidebarItem("General", systemImage: "gearshape", isSelected: true) {}
        SidebarItem("Presenting", systemImage: "play.rectangle", isSelected: false) {}
    }
    .frame(width: 200)
    .padding()
    .background(CueTheme.ground)
}
