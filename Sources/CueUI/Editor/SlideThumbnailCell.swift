import AppKit
import SwiftUI

/// One slide in the editor's sidebar: number, a real render of the slide,
/// a LIVE tag for slides with running web content, and the slide's title.
public struct SlideThumbnailCell: View {
    let number: Int
    let image: NSImage?
    let label: String
    let isLive: Bool
    let isSelected: Bool
    let aspectRatio: CGFloat

    public init(number: Int, image: NSImage?, label: String, isLive: Bool, isSelected: Bool,
                aspectRatio: CGFloat = 16 / 9) {
        self.number = number
        self.image = image
        self.label = label
        self.isLive = isLive
        self.isSelected = isSelected
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(CueTheme.textTertiary)
                .frame(width: 18, alignment: .trailing)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                picture
                HStack(spacing: 4) {
                    if isLive { LiveTag() }
                    Text(label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(CueTheme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(EdgeInsets(top: 7, leading: 4, bottom: 8, trailing: 8))
        .background(isSelected ? Color.white.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Slide \(number): \(label)\(isLive ? ", live content" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var picture: some View {
        ZStack {
            Color.black
            if let image {
                Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
            } else {
                ProgressView().controlSize(.small).tint(.white.opacity(0.5))
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    isSelected ? CueTheme.selection : Color.white.opacity(0.10), lineWidth: isSelected ? 2.5 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.4 : 0), radius: 8, y: 6)
    }
}

#Preview {
    VStack(spacing: 4) {
        SlideThumbnailCell(number: 1, image: nil, label: "Plans that hold up.", isLive: false, isSelected: false)
        SlideThumbnailCell(number: 2, image: nil, label: "One question, answered.", isLive: true, isSelected: true)
    }
    .frame(width: 210)
    .padding()
    .background(CueTheme.ground)
}
