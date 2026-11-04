import CueCore
import CueUI
import SwiftUI

/// The real screen arrangement from System Settings, scaled to fit, with
/// each screen's role. Click a screen to select it.
struct DisplayArrangementView: View {
    let coordinator: DisplayCoordinator

    var body: some View {
        GeometryReader { geometry in
            let layout = ArrangementLayout(displays: coordinator.displays, in: geometry.size)
            ZStack(alignment: .topLeading) {
                ForEach(coordinator.displays) { display in
                    let frame = layout.frame(for: display)
                    DisplayTile(
                        display: display,
                        role: coordinator.role(of: display.id),
                        isSelected: coordinator.selectedID == display.id
                    ) { coordinator.selectedID = display.id }
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                }
            }
        }
        .padding(EdgeInsets(top: 48, leading: 32, bottom: 48, trailing: 32))
        .overlay(alignment: .topLeading) {
            SectionLabel("Arrangement").padding(.leading, 20).padding(.top, 16)
        }
        .overlay(alignment: .bottomLeading) {
            Text("Click a display to change its role. Arrange screens in System Settings › Displays.")
                .font(.system(size: 12))
                .foregroundStyle(CueTheme.textTertiary)
                .padding(.leading, 20).padding(.bottom, 16)
        }
        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: CueTheme.panelRadius))
        .overlay(RoundedRectangle(cornerRadius: CueTheme.panelRadius).strokeBorder(Color.white.opacity(0.06)))
    }
}

/// Maps global screen frames (origin bottom-left) into the view (origin top-left).
struct ArrangementLayout {
    private let bounds: CGRect
    private let scale: CGFloat
    private let offset: CGPoint

    init(displays: [DisplayInfo], in size: CGSize, gap: CGFloat = 0.04) {
        let union = displays.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        bounds = union.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : union
        scale = min(size.width / bounds.width, size.height / bounds.height) * (1 - gap)
        offset = CGPoint(
            x: (size.width - bounds.width * scale) / 2,
            y: (size.height - bounds.height * scale) / 2
        )
    }

    func frame(for display: DisplayInfo) -> CGRect {
        let inset: CGFloat = 4 // Keeps touching screens visibly apart.
        let x = (display.frame.minX - bounds.minX) * scale + offset.x
        let y = (bounds.maxY - display.frame.maxY) * scale + offset.y
        return CGRect(x: x, y: y, width: display.frame.width * scale, height: display.frame.height * scale)
            .insetBy(dx: inset, dy: inset)
    }
}
