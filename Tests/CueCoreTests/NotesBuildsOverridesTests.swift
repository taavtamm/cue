import Foundation
import Testing
@testable import CueCore

@Suite("Notes, builds and overrides")
struct NotesBuildsOverridesTests {
    @Test func notesGoWhereEachFormatKeepsThem() throws {
        var demo-deck = try Editing.document("demo-deck.html")
        try demo-deck.apply(.setNotes(slide: 2, text: "Say \"three\" & <pause>"))
        #expect(demo-deck.structure.slides[2].notes == "Say \"three\" & <pause>")
        #expect(demo-deck.source.contains("data-speaker-notes=\"Say &quot;three&quot; &amp; &lt;pause>\""))

        var reveal = try Editing.document("reveal.html")
        let result = try reveal.apply(.setNotes(slide: 0, text: "Hello all."))
        #expect(reveal.structure.slides[0].notes == "Hello all.")
        #expect(reveal.source.contains("<aside class=\"notes\">Hello all.</aside>"))
        #expect({ if case .inPlace = result.live { true } else { false } }())
        try reveal.apply(.setNotes(slide: 1, text: "New aside"))
        #expect(reveal.structure.slides[1].notes == "New aside")

        var cue = try Editing.document("cue-convention.html")
        try cue.apply(.setNotes(slide: 2, text: "Demo notes"))
        #expect(cue.structure.slides[2].notes == "Demo notes")
    }

    @Test func cueBuildsBecomeAttributes() throws {
        var document = try Editing.document("cue-convention.html")
        let paragraphs = document.sourceMap.elements.filter { $0.tag == "p" }.map(\.path)
        try document.apply(.setBuilds(slide: 1, steps: [
            BuildSpec(targets: [paragraphs[3]], effect: "pop"),
            BuildSpec(targets: [paragraphs[0], paragraphs[1]]),
        ]))
        let builds = document.structure.slides[1].builds
        #expect(builds.count == 2)
        #expect(builds[0].effect == "pop")
        #expect(document.source.contains("<p data-cue-build=\"1\" data-cue-effect=\"pop\">Three</p>"))
        #expect(document.source.contains("<p>Two and a half</p>"))
    }

    @Test func claudeDesignBuildsPatchOnlyThatSlidesSteps() throws {
        var document = try Editing.document("demo-deck.html")
        let before = document.source
        let motionJSON = document.sourceMap.elements.first { $0.attributes["id"] == "deck-motion" }?.innerRange
        let slide = document.structure.slides[1]
        let frames = document.sourceMap.elements.filter {
            $0.attributes["data-frame-id"] != nil && $0.path.starts(with: slide.elementPath)
        }
        #expect(frames.count >= 2)
        let result = try document.apply(.setBuilds(slide: 1, steps: [
            BuildSpec(targets: [frames[0].path], effect: "rise"), BuildSpec(targets: [frames[1].path]),
        ]))
        #expect(document.structure.slides[1].builds.count == 2)
        #expect(document.structure.slides[1].builds[0].effect == "rise")
        #expect(document.structure.slides[0].builds.isEmpty && document.structure.slides[2].builds.isEmpty)
        #expect(result.live == .reload)
        Editing.expectWithin(motionJSON, before: before, after: document.source)
        #expect(result.edit.patches.count == 1)
    }

    @Test func overridesLiveInCuesOwnBlock() throws {
        var document = try Editing.document("cue-convention.html")
        let created = try document.apply(.setOverride(selector: "h1", property: "color", value: "#2f7bff"))
        #expect(document.source.contains("<style id=\"cue-overrides\">\nh1 { color: #2f7bff; }\n</style>\n</head>"))
        #expect(created.live == .inPlace([.setOverrides(css: "\nh1 { color: #2f7bff; }\n")], remap: true))
        try document.apply(.setOverride(selector: "h1", property: "color", value: "red"))
        try document.apply(.setOverride(selector: "h1", property: "font-size", value: "88px"))
        try document.apply(.setOverride(selector: ".lead p", property: "margin", value: "0"))
        #expect(document.source.contains("h1 { color: red; font-size: 88px; }\n.lead p { margin: 0; }\n</style>"))
        let changed = try document.apply(.setOverride(selector: "h1", property: "color", value: nil))
        #expect(changed.live == .inPlace([.setOverrides(css: "\nh1 { font-size: 88px; }\n.lead p { margin: 0; }\n")],
                                         remap: false))
        // The deck's own <style>/<link> elements are untouched.
        #expect(document.sourceMap.elements.filter { $0.tag == "style" }.count == 1)
    }
}
