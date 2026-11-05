import AppKit
import CueCore
import CueRender

/// Renders a deck for export: one offscreen surface at the slide's design
/// size (so one CSS pixel is one point), each slide in its finished state,
/// live embeds given a moment to draw. The deck itself is never changed.
@MainActor
public final class ExportRenderer {
    let document: DeckDocument
    let renderer = SlideRenderer(surface: .export)
    private let window: OffscreenRenderWindow
    private var ready: CheckedContinuation<Void, Error>?

    /// How long a slide with live web content gets to draw before it's captured.
    static let liveSettle: Duration = .milliseconds(1_500)

    public init(document: DeckDocument) {
        self.document = document
        let canvas = document.structure.canvas
        window = OffscreenRenderWindow(size: CGSize(width: canvas.width, height: canvas.height))
        window.contentView = renderer
        window.orderFrontRegardless() // WebKit only renders pages in ordered-in windows.
    }

    public var slideCount: Int { document.structure.slides.count }
    var canvasWidth: Double { document.structure.canvas.width }

    /// Loads the deck; returns once its player is ready.
    public func start() async throws {
        renderer.onEvent = { [weak self] event in
            if case .ready = event { self?.ready?.resume(); self?.ready = nil }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ready = continuation
            Task {
                do { try await renderer.load(DeckSource(document: document)) } catch {
                    ready?.resume(throwing: error)
                    ready = nil
                }
                try? await Task.sleep(for: .seconds(30))
                ready?.resume(throwing: ExportError.timedOut)
                ready = nil
            }
        }
    }

    /// Shows slide `index` finished and waits until it (and any live content) has drawn.
    func show(_ index: Int) async throws {
        try Task.checkCancellation()
        try await renderer.showNow(ShowPosition(slide: index), finished: true)
        if document.structure.slides[index].hasLiveContent { try await Task.sleep(for: Self.liveSettle) }
        await renderer.waitForPaint()
    }

    /// The slide's editable parts, marked for hiding.
    func layout(_ index: Int) async throws -> ExportLayout {
        guard let layout = try await renderer.exportLayout(
            slide: index, slideSelector: document.structure.slideSelector, canvasWidth: canvasWidth
        ) else { throw ExportError.slideNotFound(index + 1) }
        return layout
    }

    public func close() {
        window.orderOut(nil)
        window.contentView = nil
        window.close()
    }
}

public enum ExportError: Error, LocalizedError, Equatable {
    case timedOut
    case slideNotFound(Int)
    case couldNotEncode

    public var errorDescription: String? {
        switch self {
        case .timedOut: "The deck didn't finish loading for export."
        case .slideNotFound(let number): "Slide \(number) couldn't be found in the rendered deck."
        case .couldNotEncode: "A slide picture couldn't be encoded."
        }
    }
}
