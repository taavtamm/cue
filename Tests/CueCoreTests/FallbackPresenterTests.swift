import Testing
@testable import CueCore

@Suite("Fallback presenter view")
struct FallbackPresenterTests {
    @Test func everyScreenOffPutsThePresenterOnTheMainScreen() {
        var active = false
        let roles = FallbackPresenter.roles(DisplayRoles(["mac": .off, "lg": .off]), mainID: "mac", active: &active)
        #expect(roles.role(of: "mac") == .presenter)
        #expect(roles.role(of: "lg") == .off, "the other screen stays black")
        #expect(active)
    }

    @Test func addingAnAudienceScreenKeepsIt() {
        var active = true
        let roles = FallbackPresenter.roles(DisplayRoles(["mac": .off, "lg": .stage]), mainID: "mac", active: &active)
        #expect(roles.role(of: "mac") == .presenter)
        #expect(roles.role(of: "lg") == .stage)
    }

    @Test func aRealPresenterScreenReplacesIt() {
        var active = true
        let chosen = DisplayRoles(["mac": .off, "ipad": .presenter, "lg": .stage])
        #expect(FallbackPresenter.roles(chosen, mainID: "mac", active: &active) == chosen)
        #expect(!active)
    }

    @Test func notNeededWhenTheChoiceAlreadyShowsSomething() {
        var active = false
        let chosen = DisplayRoles(["mac": .off, "lg": .stage]) // The presenter chose no presenter view.
        #expect(FallbackPresenter.roles(chosen, mainID: "mac", active: &active) == chosen)
    }

    @Test func neverTakesOverAScreenThatShowsSomething() {
        var active = true
        let chosen = DisplayRoles(["mac": .stage])
        #expect(FallbackPresenter.roles(chosen, mainID: "mac", active: &active) == chosen)
    }
}
