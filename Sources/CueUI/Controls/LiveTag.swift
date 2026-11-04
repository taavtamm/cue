import SwiftUI

/// The small cyan "LIVE" tag on thumbnails of slides that hold running
/// web content.
public struct LiveTag: View {
    public init() {}

    public var body: some View {
        Text("LIVE")
            .font(.system(size: 9.5, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(CueTheme.liveText)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(CueTheme.live.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityLabel("Live content")
    }
}

#Preview { LiveTag().padding(24).background(CueTheme.ground) }
