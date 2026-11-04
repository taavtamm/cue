import SwiftUI

/// A keyboard shortcut hint in SF Mono, e.g. the "B" next to Black screen
/// or "⌘1" in the Launcher.
public struct KeyHint: View {
    let keys: String
    var size: CGFloat = 12.5

    public init(_ keys: String, size: CGFloat = 12.5) {
        self.keys = keys
        self.size = size
    }

    public var body: some View {
        Text(keys)
            .font(CueTheme.mono(size))
            .foregroundStyle(CueTheme.textSecondary)
            .monospacedDigit()
            .accessibilityLabel("Shortcut \(keys)")
    }
}

#Preview {
    HStack { Text("Black screen"); KeyHint("B") }
        .foregroundStyle(CueTheme.text).padding(24).background(CueTheme.ground)
}
