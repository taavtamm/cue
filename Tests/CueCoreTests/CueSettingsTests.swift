import Foundation
import Testing
@testable import CueCore

@Suite("App settings")
@MainActor
struct CueSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "cue-settings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsMatchTheValuesCueUsedBefore() {
        let settings = CueSettings(defaults: freshDefaults())
        #expect(settings.minutesPerSlide == 2)
        #expect(settings.cursorHideDelay == 2)
        #expect(settings.keepsDisplayAwake)
        #expect(settings.keepsAnimationsInSync)
        #expect(settings.defaultFontFamily == CueSettings.systemFont)
        #expect(settings.defaultFontSize == 48)
        #expect(settings.defaultSaveFolder == nil)
    }

    @Test func changesPersistAcrossInstances() {
        let defaults = freshDefaults()
        let first = CueSettings(defaults: defaults)
        first.minutesPerSlide = 3
        first.cursorHideDelay = 4
        first.keepsDisplayAwake = false
        first.defaultFontFamily = "Inter"
        first.defaultSaveFolder = URL(filePath: "/tmp/decks")

        let second = CueSettings(defaults: defaults)
        #expect(second.minutesPerSlide == 3)
        #expect(second.cursorHideDelay == 4)
        #expect(!second.keepsDisplayAwake)
        #expect(second.defaultFontFamily == "Inter")
        #expect(second.defaultSaveFolder?.path == "/tmp/decks")
    }

    @Test func numbersAreClampedToSensibleRanges() {
        let defaults = freshDefaults()
        let settings = CueSettings(defaults: defaults)
        settings.cursorHideDelay = 0
        settings.defaultFontSize = 9000
        #expect(settings.cursorHideDelay == 0.5)
        #expect(settings.defaultFontSize == 400)
        #expect(CueSettings(defaults: defaults).defaultFontSize == 400)
    }

    @Test func keepsTheDisplaysWindowsExistingSyncKey() {
        let defaults = freshDefaults()
        defaults.set(false, forKey: "keepsAnimationsInSync")
        #expect(!CueSettings(defaults: defaults).keepsAnimationsInSync)
    }

    @Test func resetRestoresDefaults() {
        let settings = CueSettings(defaults: freshDefaults())
        settings.minutesPerSlide = 5
        settings.defaultFontFamily = "Menlo"
        settings.reset()
        #expect(settings.minutesPerSlide == 2 && settings.defaultFontFamily == CueSettings.systemFont)
    }

    @Test func paceTargetUsesMinutesPerSlide() {
        #expect(ShowPace.defaultTarget(slideCount: 12) == 25 * 60)
        #expect(ShowPace.defaultTarget(slideCount: 12, minutesPerSlide: 3) == 40 * 60)
        #expect(ShowPace.defaultTarget(slideCount: 12, rehearsed: [60, 60], minutesPerSlide: 3) == 120)
    }
}
