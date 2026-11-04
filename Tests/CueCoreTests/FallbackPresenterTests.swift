import Testing
@testable import CueCore

@Suite("Fallback presenter view")
struct FallbackPresenterTests {
    @Test func noWindowsLeftOpensIt() {
        // Laptop set to Off, projector unplugged: nothing would be on screen.
        #expect(FallbackPresenter.decide(roles: [], fallbackIsOpen: false) == .open)
    }

    @Test func pluggingInAnAudienceScreenKeepsIt() {
        #expect(FallbackPresenter.decide(roles: [.stage], fallbackIsOpen: true) == .keep)
    }

    @Test func aRealPresenterScreenReplacesIt() {
        #expect(FallbackPresenter.decide(roles: [.stage, .presenter], fallbackIsOpen: true) == .close)
        #expect(FallbackPresenter.decide(roles: [.confidence], fallbackIsOpen: true) == .close)
    }

    @Test func withoutAFallbackNothingChanges() {
        #expect(FallbackPresenter.decide(roles: [.stage, .presenter], fallbackIsOpen: false) == .keep)
    }
}
