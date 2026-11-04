import Foundation
import IOKit.pwr_mgt

/// Keeps the displays awake while the show runs.
final class DisplaySleepAssertion {
    private var assertion: IOPMAssertionID = 0
    private(set) var isHeld = false

    func begin(reason: String) {
        guard !isHeld else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertion
        )
        isHeld = result == kIOReturnSuccess
    }

    func end() {
        guard isHeld else { return }
        IOPMAssertionRelease(assertion)
        isHeld = false
    }

    deinit { end() }
}
