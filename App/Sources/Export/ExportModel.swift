import AppKit
import CueCore
import CueExport
import Observation

/// One export from one deck window: the chosen format, the save panel, the
/// work and its progress. Exports the deck as it is now, unsaved edits
/// included; the deck itself is never changed.
@MainActor @Observable
final class ExportModel {
    var format: DeckExport.Format
    var imageScale = 2.0
    private(set) var progress: Double?
    private(set) var status = ""
    var isRunning: Bool { task != nil }

    let deckName: String
    @ObservationIgnored private let document: () -> DeckDocument
    @ObservationIgnored private weak var window: NSWindow?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored var onClose: () -> Void = {}
    @ObservationIgnored var onFinish: (Result<DeckExport.Result, Error>, DeckExport.Format) -> Void = { _, _ in }

    init(format: DeckExport.Format, document: @escaping () -> DeckDocument, window: NSWindow) {
        self.format = format
        self.document = document
        self.window = window
        deckName = document().fileURL.deletingPathExtension().lastPathComponent
    }

    func cancel() {
        task?.cancel()
        task = nil
        onClose()
    }

    func export() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.directoryURL = document().fileURL.deletingLastPathComponent()
        panel.canCreateDirectories = true
        switch format {
        case .powerPoint:
            panel.allowedContentTypes = [.init(filenameExtension: "pptx")!]
            panel.nameFieldStringValue = deckName + ".pptx"
        case .pdf:
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = deckName + ".pdf"
        case .images:
            panel.nameFieldStringValue = deckName + " images"
            panel.message = "Cue makes this folder and puts one PNG per slide in it."
        }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.run(to: url)
        }
    }

    private func run(to url: URL) {
        let document = document(), format = format, scale = imageScale
        progress = 0
        status = "Rendering slide 1…"
        task = Task { [weak self] in
            let report: DeckExport.Progress = { done, total in
                self?.progress = Double(done) / Double(max(1, total))
                self?.status = done < total ? "Rendering slide \(done + 1) of \(total)…" : "Writing the file…"
            }
            let result: Result<DeckExport.Result, Error>
            do {
                switch format {
                case .powerPoint: result = .success(try await DeckExport.powerPoint(document, to: url, progress: report))
                case .pdf: result = .success(try await DeckExport.pdf(document, to: url, progress: report))
                case .images: result = .success(try await DeckExport.images(document, to: url, scale: scale, progress: report))
                }
            } catch is CancellationError {
                return
            } catch {
                result = .failure(error)
            }
            self?.task = nil
            self?.onFinish(result, format)
        }
    }
}
