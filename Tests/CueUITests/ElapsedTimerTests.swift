import Testing
@testable import CueUI

@Test func elapsedTimerFormats() {
    #expect(ElapsedTimer.format(0) == "00:00")
    #expect(ElapsedTimer.format(768) == "12:48")
    #expect(ElapsedTimer.format(3725) == "1:02:05")
    #expect(ElapsedTimer.format(-5) == "00:00")
}
