import AppKit
import CueImport
import CueUI
import SwiftUI

/// Turns PowerPoint, Keynote, OpenDocument and PDF files into HTML decks
/// before they open: progress while converting, a question when Cue's
/// earlier copy is out of date, errors as a banner, the report afterwards.
@MainActor
final class ImportCoordinator {
    typealias Open = (_ html: URL, _ report: ImportReport?) -> Void

    private let service = ImportService()
    private var panels: [ImportPanel] = []

    static let keynoteStore = URL(string: "macappstore://apps.apple.com/app/id409183694")!

    /// Prepares `url` and calls `open` with the HTML deck to open.
    func open(_ url: URL, replacingCopy: Bool = false, then open: @escaping Open) {
        let route = Self.routeDescription(for: url, keynoteInstalled: service.keynote.isInstalled)
        let progress = ImportPanel { ImportProgressView(fileName: url.lastPathComponent, route: route) }
        progress.show()
        panels.append(progress)
        Task {
            defer { self.dismiss(progress) }
            do {
                let prepared = try await service.prepare(url, replacingCopy: replacingCopy)
                if prepared.reusedCopy?.originalIsNewer == true {
                    askToConvertAgain(url, copy: prepared.htmlURL, then: open)
                } else {
                    open(prepared.htmlURL, prepared.report)
                }
            } catch {
                showError(error, for: url)
            }
        }
    }

    /// Shown non-modally over the deck's window after it opens.
    func showReport(_ report: ImportReport, over window: NSWindow?) {
        var panel: ImportPanel?
        let needsKeynote = report.isPresentOnly && report.route == "Keynote preview"
        panel = ImportPanel(width: 560) {
            ImportReportView(
                report: report,
                onGetKeynote: needsKeynote ? { NSWorkspace.shared.open(Self.keynoteStore) } : nil,
                onDismiss: { [weak self] in if let panel { self?.dismiss(panel) } }
            )
        }
        guard let panel else { return }
        panels.append(panel)
        panel.show(over: window)
    }

    private func askToConvertAgain(_ url: URL, copy: URL, then open: @escaping Open) {
        var panel: ImportPanel?
        panel = ImportPanel {
            Banner(
                systemImage: "arrow.triangle.2.circlepath",
                message: "“\(url.lastPathComponent)” changed since Cue converted it.",
                detail: "Converting again replaces Cue's copy, including edits made in Cue.",
                actions: [
                    .init("Convert again", kind: .primary) { [weak self] in
                        if let panel { self?.dismiss(panel) }
                        self?.open(url, replacingCopy: true, then: open)
                    },
                    .init("Open Cue's copy") { [weak self] in
                        if let panel { self?.dismiss(panel) }
                        open(copy, nil)
                    },
                ]
            )
        }
        if let panel {
            panels.append(panel)
            panel.show()
        }
    }

    private func showError(_ error: any Error, for url: URL) {
        var panel: ImportPanel?
        var actions: [Banner.Action] = [.init("OK") { [weak self] in if let panel { self?.dismiss(panel) } }]
        if case ImportError.needsKeynote = error {
            actions.insert(.init("Get Keynote", kind: .primary) { NSWorkspace.shared.open(Self.keynoteStore) }, at: 0)
        }
        if case ImportError.automationDenied = error {
            actions.insert(.init("Open Settings", kind: .primary) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
            }, at: 0)
        }
        panel = ImportPanel(width: 600) {
            Banner(systemImage: "exclamationmark.triangle", message: "Cue couldn't open “\(url.lastPathComponent)”.",
                   detail: error.localizedDescription, actions: actions)
        }
        if let panel {
            panels.append(panel)
            panel.show()
        }
    }

    private func dismiss(_ panel: ImportPanel) {
        panel.close()
        panels.removeAll { $0 === panel }
    }

    static func routeDescription(for url: URL, keynoteInstalled: Bool) -> String {
        switch url.pathExtension.lowercased() {
        case "pptx": "Reading PowerPoint slides, text, pictures and notes"
        case "pdf": "Drawing each page as a slide"
        case "key", "ppt", "odp" where keynoteInstalled: "Asking Keynote for a PowerPoint copy, then converting it"
        case "odp": "Reading OpenDocument text, pictures and notes"
        default: "Reading the presentation"
        }
    }
}
