import CueCore
import CueEditor
import Foundation
import Testing

@Suite("Breadcrumb, build plan and source excerpt", .serialized)
struct ModelTests {
    @Test func breadcrumbRunsFromTheSlideToTheElement() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("demo-deck.html"))
        let heading = try #require(document.heading(onSlide: 2))
        let items = Breadcrumb.items(
            for: heading.path, slidePath: document.structure.slides[2].elementPath, in: document.sourceMap
        )
        #expect(items.first == "section.deck-slide#3")
        #expect(items.contains("div.deck-scaler"))
        #expect(items.last == "div")
        #expect(items.count == heading.path.count - document.structure.slides[2].elementPath.count + 1)
    }

    @Test func buildPlanTracesCueBuildsToTheirElements() async throws {
        let document = try await EditorFixture.document(try EditorFixture.copy("cue-convention.html"))
        let slide = try #require(document.structure.slides.first { !$0.builds.isEmpty })
        var plan = BuildPlan(slide: slide, map: document.sourceMap, tree: document.tree)
        #expect(plan.isEditable)
        #expect(plan.steps.count == 3)
        #expect(plan.steps[0].title == "One" && plan.steps[0].effect == "rise")
        #expect(plan.steps[1].targets.count == 2)
        plan.move(0, by: 1)
        #expect(plan.specs.map(\.targets.count) == [2, 1, 1])
    }

    @Test func buildPlanReordersThroughTheSourceEditor() async throws {
        var document = try await EditorFixture.document(try EditorFixture.copy("cue-convention.html"))
        let index = try #require(document.structure.slides.firstIndex { !$0.builds.isEmpty })
        var plan = BuildPlan(slide: document.structure.slides[index], map: document.sourceMap, tree: document.tree)
        plan.move(0, by: 1)
        try document.apply(.setBuilds(slide: index, steps: plan.specs))
        let after = BuildPlan(slide: document.structure.slides[index], map: document.sourceMap, tree: document.tree)
        #expect(after.steps.map(\.title) == plan.steps.map(\.title))
        #expect(after.steps[1].title == "One" && after.steps[1].effect == "rise")
    }
}
