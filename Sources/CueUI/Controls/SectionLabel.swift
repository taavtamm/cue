import SwiftUI

/// The uppercase 11 pt section heading used in sidebars, the inspector
/// and the presenter view ("SLIDES", "TYPOGRAPHY", "NOTES").
public struct SectionLabel: View {
    let title: String
    var size: CGFloat = 11

    public init(_ title: String, size: CGFloat = 11) {
        self.title = title
        self.size = size
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: size, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(CueTheme.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview { SectionLabel("Typography").padding(24).background(CueTheme.ground) }
