import AppKit
import CueExport
import SwiftUI

/// File › Export. Each deck window keeps its own export sheet and result panel.
extension DeckWindowController {
    @objc func exportDeck(_ sender: Any?) { beginExport(.powerPoint) }
    @objc func exportPowerPoint(_ sender: Any?) { beginExport(.powerPoint) }
    @objc func exportPDF(_ sender: Any?) { beginExport(.pdf) }
    @objc func exportImages(_ sender: Any?) { beginExport(.images) }

    private func beginExport(_ format: DeckExport.Format) {
        guard let window, window.attachedSheet == nil else { return }
        let model = ExportModel(format: format, document: { [unowned self] in session.document }, window: window)
        let sheet = NSWindow(contentViewController: NSHostingController(rootView: ExportSheet(model: model)))
        let results = ExportWindows.results(for: window)
        model.onClose = { [weak window, weak sheet] in
            if let sheet { window?.endSheet(sheet) }
        }
        model.onFinish = { [weak window, weak sheet] result, format in
            guard let window else { return }
            if let sheet { window.endSheet(sheet) }
            results.show(result, format: format, over: window)
        }
        ExportWindows.models[ObjectIdentifier(window)] = model // Kept while the sheet is up.
        window.beginSheet(sheet) { _ in ExportWindows.models[ObjectIdentifier(window)] = nil }
    }
}

/// Keeps each deck window's export model and result panel alive.
@MainActor
enum ExportWindows {
    static var models: [ObjectIdentifier: ExportModel] = [:]
    private static var panels: [ObjectIdentifier: ExportResultPanel] = [:]

    static func results(for window: NSWindow) -> ExportResultPanel {
        if let panel = panels[ObjectIdentifier(window)] { return panel }
        let panel = ExportResultPanel()
        panels[ObjectIdentifier(window)] = panel
        return panel
    }
}
