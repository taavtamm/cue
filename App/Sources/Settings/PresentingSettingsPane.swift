import CueCore
import CueUI
import SwiftUI

/// Show defaults. A deck's own target length (from rehearsal) wins over these.
struct PresentingSettingsPane: View {
    @Bindable var settings: CueSettings

    var body: some View {
        SettingsGroup("Timer", footnote: "Used when a deck has no rehearsed timings. Rounded up to five minutes.") {
            SettingsRow("Minutes per slide", detail: "For the talk length in the presenter view") {
                number(settings.minutesPerSlide, unit: "min") { settings.minutesPerSlide = $0 }
            }
        }
        SettingsGroup("During the show") {
            SettingsRow("Hide the cursor after", detail: "Seconds without moving the mouse") {
                number(settings.cursorHideDelay, unit: "sec") { settings.cursorHideDelay = $0 }
            }
            SettingsDivider()
            SettingsRow("Keep the display awake", detail: "Stops the screen dimming or sleeping mid-show") {
                SettingsSwitch("Keep the display awake", isOn: $settings.keepsDisplayAwake)
            }
            SettingsDivider()
            SettingsRow("Keep animations in sync across screens", detail: "Mirrored screens line up on each slide") {
                SettingsSwitch("Keep animations in sync", isOn: $settings.keepsAnimationsInSync)
            }
        }
    }

    private func number(_ value: Double, unit: String, set: @escaping (Double) -> Void) -> some View {
        InspectorField(unit, value: value.formatted(.number.precision(.fractionLength(0...1))), placement: .leading) {
            if let parsed = Double($0.replacingOccurrences(of: ",", with: ".")) { set(parsed) }
        }
        .frame(width: 96)
    }
}
