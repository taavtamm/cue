import AppKit
import CueCore
import CueEditor
import Foundation
import Testing
@testable import CueRender

/// The editor session on a real WKWebView showing the demo deck.
@Suite("Editor session on the demo deck", .serialized)
@MainActor
struct SessionTests {
    private func open(slide: Int = 0) async throws -> (SessionHarness, DeckDocument) {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        try await harness.load(slide: slide)
        return (harness, document)
    }

    @Test func clickingAnElementSelectsItsSource() async throws {
        let (harness, document) = try await open(slide: 2)
        defer { harness.close() }
        let heading = try #require(document.heading(onSlide: 2))
        let point = try await harness.centre(of: heading.cueID)

        let selected = await harness.session.click(at: point)
        #expect(selected?.cueID == heading.cueID)
        #expect(selected?.breadcrumb.first == "section.deck-slide#3")
        let startTag = try #require(heading.startTag)
        #expect(document.text(startTag).hasPrefix("<div"))
        #expect(document.text(startTag).contains("role=\"heading\""))
        // The deck sets the size inline; the inspector reads the page's computed value.
        let declared = heading.attributes["style"]?.firstMatch(of: /font-size: (\d+)px/).map { String($0.1) }
        #expect(declared != nil && harness.session.selection?.values.fontSize == declared)
        #expect(harness.session.selection?.kind == .text)
    }

    @Test func inlineTextEditChangesOnlyThatElementsText() async throws {
        let (harness, original) = try await open(slide: 2)
        defer { harness.close() }
        let heading = try #require(original.heading(onSlide: 2))
        let inner = try #require(heading.innerRange)
        _ = await harness.session.click(at: try await harness.centre(of: heading.cueID))

        await harness.session.beginInlineEdit()
        #expect(harness.session.inlineEdit != nil)
        _ = try await harness.session.canvas.evaluateInBridge(
            "window.__cue.sourceMap.element('\(heading.cueID)').textContent = 'One question & done.'"
        )
        await harness.session.endInlineEdit(commit: true)
        try await harness.waitUntil("edit applied") { harness.session.document.isDirty }
        try await harness.waitUntil("edit chain idle") { harness.session.inlineEdit == nil }

        let before = original.source as NSString
        let after = harness.session.document.source as NSString
        let prefix = before.substring(to: inner.start)
        let suffix = before.substring(from: inner.end)
        #expect(after.hasPrefix(prefix))
        #expect(after.hasSuffix(suffix))
        let newLength = after.length - inner.start - (before.length - inner.end)
        let middle = after.substring(with: NSRange(location: inner.start, length: newLength))
        #expect(middle == "One question &amp; done.")
        let live = try await harness.session.canvas.evaluateInBridge(
            "return window.__cue.sourceMap.element('\(heading.cueID)').textContent"
        ) as? String
        #expect(live == "One question & done.")
    }

    @Test func notesTypedInQuickSuccessionUndoAsOne() async throws {
        let (harness, original) = try await open()
        defer { harness.close() }
        await harness.session.apply(.setNotes(slide: 0, text: "First"))
        await harness.session.apply(.setNotes(slide: 0, text: "First draft"))
        #expect(harness.session.document.history.undoCount == 1)
        #expect(harness.session.currentSlide?.notes == "First draft")
        await harness.session.undo()
        #expect(harness.session.document.source == original.source)
        #expect(!harness.session.isDirty)
    }

    @Test func inspectorEditPatchesInlineStyleAndUndoes() async throws {
        let (harness, original) = try await open(slide: 2)
        defer { harness.close() }
        let heading = try #require(original.heading(onSlide: 2))
        _ = await harness.session.click(at: try await harness.centre(of: heading.cueID))

        await harness.session.setStyle(.fontSize, to: "60")
        let after = try #require(harness.session.document.sourceMap.element(at: heading.path))
        let style = try #require(after.attributes["style"])
        #expect(style.contains("font-size: 60px") || style.contains("font-size:60px"))
        try await harness.waitUntil("inspector caught up") { harness.session.selection?.values.fontSize == "60" }

        await harness.session.undo()
        #expect(harness.session.document.source == original.source)
    }

    @Test func refusedValuesNeverReachTheFile() async throws {
        let (harness, original) = try await open(slide: 2)
        defer { harness.close() }
        let heading = try #require(original.heading(onSlide: 2))
        _ = await harness.session.click(at: try await harness.centre(of: heading.cueID))
        await harness.session.setStyle(.fontSize, to: "huge")
        #expect(harness.session.lastError != nil)
        #expect(harness.session.document.source == original.source)
    }

    @Test func timelineListsTheSlidesLiveContent() async throws {
        let (harness, document) = try await open(slide: 5)
        defer { harness.close() }
        #expect(document.structure.slides[5].hasLiveContent)
        try await harness.waitUntilAsync("embeds running") {
            await harness.session.refreshAnimations()
            return harness.session.animations.embedCount > 0
        }
        #expect(harness.session.timeline.rows.allSatisfy { !$0.title.localizedCaseInsensitiveContains("embed") })
    }

    /// Slide 1 runs a live embed as a full-slide background with text on
    /// top. Double-clicking that text must edit it, not wake the embed.
    @Test func doubleClickOnTextAboveABackgroundEmbedEditsTheText() async throws {
        let (harness, document) = try await open(slide: 0)
        defer { harness.close() }
        _ = try await harness.waitForEmbed()
        let heading = try #require(document.heading(onSlide: 0))
        await harness.session.doubleClick(at: try await harness.centre(of: heading.cueID))
        #expect(harness.session.interactiveEmbed == nil)
        #expect(harness.session.inlineEdit != nil)
        harness.session.clearSelection()
    }

    @Test func doubleClickOnALiveEmbedLetsItTakeClicks() async throws {
        let (harness, _) = try await open(slide: 5)
        defer { harness.close() }
        let frame = try await harness.waitForEmbed()
        await harness.session.doubleClick(at: CGPoint(x: frame.midX, y: frame.midY))
        #expect(harness.session.interactiveEmbed != nil)
        let inert = try await harness.session.canvas.evaluateInBridge(
            "return Array.from(document.querySelectorAll('iframe[srcdoc]')).some((f) => f.hasAttribute('inert'))"
        ) as? Bool
        #expect(inert == false)
        harness.session.clearSelection()
        try await harness.waitUntilAsync("embeds inert again") {
            let inertAgain = try? await harness.session.canvas.evaluateInBridge(
                "return Array.from(document.querySelectorAll('iframe[srcdoc]')).every((f) => f.hasAttribute('inert'))"
            ) as? Bool
            return inertAgain == true
        }
    }
}

extension SessionHarness {
    /// The first running embed's box, once the slide has started it.
    func waitForEmbed() async throws -> CGRect {
        var found: CGRect?
        try await waitUntilAsync("an embed on screen") {
            let rect = try? await self.session.canvas.evaluateInBridge("""
                const f = document.querySelector('iframe[srcdoc]');
                if (!f) return null;
                const r = f.getBoundingClientRect();
                return r.width > 0 ? { x: r.x, y: r.y, width: r.width, height: r.height } : null;
                """) as? [String: Double]
            guard let rect else { return false }
            found = self.session.canvas.viewRect(fromCSS: CGRect(
                x: rect["x"] ?? 0, y: rect["y"] ?? 0, width: rect["width"] ?? 0, height: rect["height"] ?? 0
            ))
            return true
        }
        return try #require(found)
    }
}

/// Play while typing on the slide: the show must get the typed text.
@Suite("Finishing interactions", .serialized)
@MainActor
struct FinishInteractionsTests {
    @Test func finishingWaitsForTheTypedTextToLand() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let harness = SessionHarness(document)
        defer { harness.close() }
        try await harness.load(slide: 2)
        let heading = try #require(document.heading(onSlide: 2))
        _ = await harness.session.click(at: try await harness.centre(of: heading.cueID))
        await harness.session.beginInlineEdit()
        #expect(harness.session.inlineEdit != nil)
        _ = try await harness.session.canvas.evaluateInBridge(
            "document.querySelector('[contenteditable]').textContent = 'Typed just before Play'; return true"
        )
        await harness.session.finishInteractions()
        #expect(harness.session.inlineEdit == nil)
        #expect(harness.session.document.source.contains("Typed just before Play"))
    }
}
