import AppKit
import SwiftUI

/// A recent deck on the Welcome window: a real render of its first slide,
/// its name and where it lives.
public struct RecentDeckCell: View {
    let name: String
    let location: String
    let image: NSImage?
    let action: () -> Void
    @State private var hovering = false

    public init(name: String, location: String, image: NSImage?, action: @escaping () -> Void) {
        self.name = name
        self.location = location
        self.image = image
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                picture
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(location)
                        .font(.system(size: 11))
                        .foregroundStyle(CueTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .padding(.horizontal, 2)
            }
            .foregroundStyle(CueTheme.text)
            .padding(8)
            .background(Color.white.opacity(hovering ? 0.08 : 0.03), in: shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(location)
        .accessibilityLabel("Open \(name)")
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }

    private var picture: some View {
        ZStack {
            Color.black
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
            } else {
                ProgressView().controlSize(.small).tint(.white.opacity(0.5))
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
    }
}

#Preview {
    HStack {
        RecentDeckCell(name: "demo-deck.html", location: "~/Documents/Cue Decks", image: nil) {}
        RecentDeckCell(name: "Quarterly review.html", location: "~/Desktop", image: nil) {}
    }
    .frame(width: 480)
    .padding()
    .background(CueTheme.ground)
}
