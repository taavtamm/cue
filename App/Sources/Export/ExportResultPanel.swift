import AppKit
import CueExport
import CueUI
import SwiftUI

/// After an export: a small glass panel floating at the bottom of the deck
/// window (non-modal), with Reveal in Finder and, for PowerPoint, the fonts
/// this Mac doesn't have that PowerPoint may substitute.
@MainActor
final class ExportResultPanel {
    private var panel: NSPanel?

    func show(_ result: Result<DeckExport.Result, Error>, format: DeckExport.Format, over window: NSWindow) {
        close()
        let view = ExportResultView(result: result, format: format) { [weak self] in self?.close() }
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        let frame = CGRect(x: window.frame.midX - size.width / 2, y: window.frame.minY + 24, width: size.width, height: size.height)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = hosting
        window.addChildWindow(panel, ordered: .above)
        self.panel = panel
    }

    func close() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
    }
}

struct ExportResultView: View {
    let result: Result<DeckExport.Result, Error>
    let format: DeckExport.Format
    let onDone: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let detail { Text(detail).font(.system(size: 11.5)).foregroundStyle(CueTheme.textSecondary) }
            }
            .frame(maxWidth: 380, alignment: .leading)
            if case .success(let export) = result {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([export.url]) }
                    .buttonStyle(.cue(height: 28))
            }
            Button("Done", action: onDone).buttonStyle(.cue(.primary, height: 28))
        }
        .padding(14)
        .foregroundStyle(CueTheme.text)
        .cueGlass(.panel)
        .fixedSize()
    }

    private var icon: String {
        if case .success = result { return "checkmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    private var tint: Color {
        if case .success = result { return CueTheme.successBright }
        return CueTheme.destructive
    }

    private var title: String {
        switch result {
        case .success(let export): "Exported \(export.slides) slides as \(name) · \(export.url.lastPathComponent)"
        case .failure: "The export didn't finish"
        }
    }

    private var detail: String? {
        switch result {
        case .failure(let error): return error.localizedDescription
        case .success(let export) where !export.missingFonts.isEmpty:
            return "Not installed on this Mac, so PowerPoint may substitute: " + export.missingFonts.joined(separator: ", ")
        case .success: return nil
        }
    }

    private var name: String {
        switch format {
        case .powerPoint: "PowerPoint"
        case .pdf: "PDF"
        case .images: "images"
        }
    }
}
