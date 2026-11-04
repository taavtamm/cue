import AppKit
import CueCore
import CueEditor
import Foundation
@testable import CueRender

/// Test decks copied to temp folders, and an editor session on screen.
enum EditorFixture {
    static let repoRoot = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func copy(_ name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-editor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let copy = folder.appending(path: "deck.html")
        try FileManager.default.copyItem(at: repoRoot.appending(path: "fixtures/\(name)"), to: copy)
        return copy
    }

    static func write(_ html: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "cue-editor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "deck.html")
        try Data(html.utf8).write(to: file)
        return file
    }

    /// Parsing without JIT (as under `swift test`) takes about a second for
    /// the big deck; off the main thread so WebKit callbacks aren't held up.
    static func document(_ url: URL) async throws -> DeckDocument {
        try await Task.detached { try DeckDocument(contentsOf: url) }.value
    }
}

/// An editor session whose canvas is in an on-screen-sized window, loaded and mapped.
@MainActor
final class SessionHarness {
    let session: EditorSession
    let window: NSWindow

    init(_ document: DeckDocument, size: CGSize = CGSize(width: 1280, height: 720)) {
        session = EditorSession(document: document)
        window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -4000, y: 0), size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = session.canvas
        window.orderFrontRegardless() // WebKit renders only windows on screen.
    }

    func load(slide: Int = 0) async throws {
        try await session.loadCanvas()
        try await waitUntil("mapped") { self.session.canvas.lastMapping != nil }
        session.showSlide(slide)
        try await waitUntilAsync("slide \(slide)") {
            let current = try? await self.session.canvas.evaluateInBridge("return window.__cue.debug().current.slide")
            return current as? Int == slide
        }
    }

    func waitUntil(_ what: String, timeout: TimeInterval = 20, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw HarnessTimeout(what: what) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    func waitUntilAsync(_ what: String, timeout: TimeInterval = 15, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !condition() {
            if Date() > deadline { throw HarnessTimeout(what: what) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// The centre of a source element on the canvas, in the canvas's own coordinates.
    func centre(of cueID: String) async throws -> CGPoint {
        let inspection = try await session.canvas.inspect(
            cueID: cueID, slideSelector: session.structure.slideSelector, canvasWidth: session.structure.canvas.width
        )
        guard let frame = inspection?.frame else { throw HarnessTimeout(what: "element \(cueID) on screen") }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    func close() { window.orderOut(nil) }
}

struct HarnessTimeout: Error { let what: String }

extension DeckDocument {
    /// The first heading (`role="heading"` or h1–h3) on a slide.
    func heading(onSlide index: Int) -> MappedElement? {
        let slide = structure.slides[index].elementPath
        return sourceMap.elements.first { element in
            element.path.starts(with: slide)
                && (element.attributes["role"] == "heading" || ["h1", "h2", "h3"].contains(element.tag))
        }
    }

    /// The source text of a range, by UTF-16 offsets.
    func text(_ range: SourceRange) -> String {
        (source as NSString).substring(with: NSRange(location: range.start, length: range.length))
    }
}
