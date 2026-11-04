import CueCore
import Foundation
import Testing
@testable import CueRender

/// Source mapping and live edits on a real WKWebView showing the Fernwick deck.
@Suite("Live source mapping and edits", .serialized)
@MainActor
struct LiveEditingTests {
    /// Attributes Cue's player adds or toggles at runtime; not in the source.
    static let runtimeAttributes: Set<String> = [
        "data-cue-id", "data-off", "inert", "aria-hidden", "data-embed-under", "data-embed-pic",
        "data-build-hidden", "data-leaving", "data-magic-hidden",
    ]

    /// Parsing the 2 MB deck takes over a second without JIT. Doing it off the
    /// main thread keeps other suites' WebKit callbacks (e.g. the sandbox's
    /// dialog timing test) from waiting behind it.
    private nonisolated static func edited(
        _ document: DeckDocument, _ operation: EditOperation
    ) async throws -> (DeckDocument, EditResult) {
        try await Task.detached {
            var copy = document
            let result = try copy.apply(operation)
            return (copy, result)
        }.value
    }

    private func open() async throws -> (RendererHarness, DeckDocument) {
        let url = try Fixture.demo-deckCopy()
        let document = try await Task.detached { try DeckDocument(contentsOf: url) }.value
        let harness = RendererHarness(surface: .editor)
        harness.renderer.sourceManifest = document.liveManifest
        try await harness.load(DeckSource(document: document))
        try await harness.waitUntil("source mapped") { harness.renderer.lastMapping != nil }
        return (harness, document)
    }

    @Test func theLiveDOMMapsOneToOneOntoTheSource() async throws {
        let (harness, document) = try await open()
        defer { harness.close() }
        let report = try #require(harness.renderer.lastMapping)
        #expect(report.exact, "\(report)")
        #expect(report.mapped == document.liveManifest.count)
    }

    @Test func clicksResolveToTheElementsSourceRange() async throws {
        let (harness, document) = try await open()
        defer { harness.close() }
        try await harness.show(ShowPosition(slide: 0), finished: true)
        // Boxes on the showing slide that are hit-testable at their centre.
        // Inline pieces (font, span…) resolve to their text box instead; the
        // editor's InlineTextSelectionTests cover that.
        let targets: [[String: Any]] = try await harness.evaluate("""
            const slide = document.querySelectorAll('section.deck-slide')[0];
            return Array.from(slide.querySelectorAll('[data-cue-id]')).filter((el) => {
              if (['inline', 'contents'].includes(getComputedStyle(el).display)) return false;
              const r = el.getBoundingClientRect();
              if (r.width < 4 || r.height < 4) return false;
              return document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2) === el;
            }).slice(0, 6).map((el) => {
              const r = el.getBoundingClientRect();
              const attrs = {};
              for (const a of el.attributes) attrs[a.name] = a.value;
              const x = r.x + r.width / 2;
              const y = r.y + r.height / 2;
              return { id: el.getAttribute('data-cue-id'), x, y, tag: el.localName, attrs };
            });
            """)
        #expect(targets.count >= 3)
        let text = document.source as NSString
        for target in targets {
            let x = target["x"] as? Double ?? 0
            let y = target["y"] as? Double ?? 0
            let point = CGPoint(x: x, y: harness.renderer.bounds.height - y)
            let hit = try #require(try await harness.renderer.element(at: point))
            #expect(hit.cueID == target["id"] as? String)
            let element = try #require(document.element(cueID: hit.cueID))
            let startTag = try #require(element.startTag)
            let sourceStart = text.substring(with: NSRange(location: startTag.start, length: startTag.length))
            #expect(sourceStart.lowercased().hasPrefix("<\(target["tag"] as? String ?? "")"))
            // The live element's attributes are the source's, plus runtime markers.
            let live = (target["attrs"] as? [String: String] ?? [:]).filter { !Self.runtimeAttributes.contains($0.key) }
            #expect(live == element.attributes, "\(sourceStart)")
        }
    }

    @Test func textAndStyleEditsApplyInPlace() async throws {
        var (harness, document) = try await open()
        defer { harness.close() }
        try await harness.show(ShowPosition(slide: 0), finished: true)
        let _: Bool = try await harness.evaluate("window.__cue.reloadMarker = true; return true")
        let slide = document.structure.slides[0].elementPath
        let leaf = try #require(document.sourceMap.elements.first {
            $0.path.starts(with: slide) && $0.isLeaf && $0.innerRange != nil && $0.tag == "div"
                && $0.attributes["data-text-path"] != nil
        })
        let textEdit: EditResult
        (document, textEdit) = try await Self.edited(document, .setText(leaf.path, "Edited live & fast"))
        try await harness.renderer.applyLive(textEdit.live, from: document)
        let text: String = try await harness.evaluate(
            "return window.__cue.sourceMap.element('\(leaf.cueID)').textContent")
        #expect(text == "Edited live & fast")

        let styleEdit: EditResult
        let red = EditOperation.setStyle(leaf.path, property: "color", value: "rgb(255, 0, 0)")
        (document, styleEdit) = try await Self.edited(document, red)
        try await harness.renderer.applyLive(styleEdit.live, from: document)
        let color: String = try await harness.evaluate(
            "return getComputedStyle(window.__cue.sourceMap.element('\(leaf.cueID)')).color")
        #expect(color == "rgb(255, 0, 0)")
        let notReloaded: Bool = try await harness.evaluate("return window.__cue.reloadMarker === true")
        #expect(notReloaded)
        let provenance = try #require(try await harness.renderer.styleSource(cueID: leaf.cueID, property: "color"))
        #expect(provenance.origin == .inline)
    }

    @Test func overridesCreateCuesBlockAndKeepTheMappingExact() async throws {
        var (harness, document) = try await open()
        defer { harness.close() }
        let slideElement = try #require(document.sourceMap.element(at: document.structure.slides[0].elementPath))
        let overflow = try await harness.renderer.styleSource(cueID: slideElement.cueID, property: "overflow")
        let before = try #require(overflow)
        #expect(before.origin == .stylesheet)
        #expect(before.selector?.contains("deck-slide") == true, "\(before)")
        #expect(before.summary.hasPrefix("from deck stylesheet"))

        let result: EditResult
        let outline = EditOperation.setOverride(
            selector: ".deck-slide", property: "outline", value: "3px solid rgb(47, 123, 255)"
        )
        (document, result) = try await Self.edited(document, outline)
        try await harness.renderer.applyLive(result.live, from: document)
        #expect(harness.renderer.lastMapping?.exact == true)
        let slideID = try #require(document.sourceMap.element(at: document.structure.slides[0].elementPath)).cueID
        let outlineStyle = try await harness.renderer.styleSource(cueID: slideID, property: "outline-style")
        let after = try #require(outlineStyle)
        #expect(after.origin == .cueOverrides)
        #expect(after.computed == "solid")
    }

    @Test func structuralEditsReloadAtTheSameSlide() async throws {
        var (harness, document) = try await open()
        defer { harness.close() }
        try await harness.show(ShowPosition(slide: 3), finished: true)
        let result: EditResult
        (document, result) = try await Self.edited(document, .addSlide(after: 0, html: nil))
        #expect(result.live == .reload)
        try await harness.renderer.applyLive(result.live, from: document)
        try await harness.waitUntil("reloaded") { harness.renderer.isReady && harness.renderer.slideCount == 13 }
        try await harness.waitUntil("remapped") { harness.renderer.lastMapping?.mapped == document.liveManifest.count }
        let current: Int = try await harness.evaluate("return window.__cue.debug().current.slide")
        #expect(current == 3)
    }
}
