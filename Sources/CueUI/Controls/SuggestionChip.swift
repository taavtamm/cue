import SwiftUI

/// A quiet capsule with a suggested request, e.g. "Tighten headline".
public struct SuggestionChip: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(hovering ? CueTheme.controlFillHover : CueTheme.controlFill, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

#Preview { SuggestionChip("Tighten headline") {}.padding(24).background(CueTheme.ground) }
