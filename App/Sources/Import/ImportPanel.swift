import AppKit
import CueUI
import SwiftUI

/// A small floating glass panel for import progress, questions, errors and
/// the import report. Non-modal: the rest of Cue stays usable.
@MainActor
final class ImportPanel {
    private let panel: NSPanel

    init<Content: View>(width: CGFloat = 520, @ViewBuilder content: () -> Content) {
        panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: width, height: 10),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        let host = NSHostingView(rootView: content().frame(width: width).fixedSize(horizontal: false, vertical: true))
        host.sizingOptions = [.preferredContentSize]
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
    }

    /// Shows the panel near the top of `window`, or of the main screen.
    func show(over window: NSWindow? = nil) {
        let area = window?.frame ?? NSScreen.main?.visibleFrame ?? .zero
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: area.midX - size.width / 2, y: area.maxY - size.height - 72))
        panel.orderFrontRegardless()
    }

    func close() { panel.orderOut(nil) }
}

/// Progress while a presentation is converted.
struct ImportProgressView: View {
    let fileName: String
    let route: String

    var body: some View {
        HStack(spacing: 14) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("Converting “\(fileName)”…").font(.system(size: 13, weight: .semibold))
                Text(route).font(.system(size: 11.5)).foregroundStyle(CueTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(CueTheme.text)
        .padding(16)
        .cueGlass(.panel)
    }
}
