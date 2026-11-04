import SwiftUI

/// The line that shows where a dragged item will land: a short glowing bar
/// in the selection blue.
public struct DropIndicator: View {
    public init() {}

    public var body: some View {
        Capsule()
            .fill(CueTheme.selection)
            .frame(height: 3)
            .shadow(color: CueTheme.selection.opacity(0.7), radius: 4)
            .padding(.horizontal, 6)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.3)).frame(height: 60)
        DropIndicator()
        RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.3)).frame(height: 60)
    }
    .padding()
    .frame(width: 240)
    .background(CueTheme.ground)
}
