import CueEditor
import CueUI
import SwiftUI

/// "Fit" / "200%" beside the Playing-live toggle, with the zoom steps.
/// Pinch, ⌘+ ⌘− and ⌘0 work on the canvas too.
struct ZoomMenu: View {
    let zoom: CanvasZoom

    var body: some View {
        Menu {
            Button("Fit Slide  ⌘0") { zoom.set(1) }
            Divider()
            ForEach(CanvasZoom.steps.dropFirst(), id: \.self) { step in
                Button("\(Int(step * 100))%") { zoom.set(step) }
            }
        } label: {
            Text(zoom.readout)
                .font(.system(size: 11.5).monospacedDigit())
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10)))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Zoom: pinch, ⌘+ / ⌘− / ⌘0")
        .accessibilityLabel("Zoom \(zoom.readout)")
    }
}
