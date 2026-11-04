import AppKit
import CueUI
import SwiftUI

/// A colour swatch that opens the system colour picker. Changes are written
/// a moment after the picker stops moving, so dragging across the wheel
/// makes one edit, not hundreds.
struct ColourWell: View {
    let hex: String
    let onChange: (String) -> Void
    @State private var colour = Color.clear
    @State private var pending: Task<Void, Never>?

    var body: some View {
        ColorPicker("", selection: $colour, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 26, height: 22)
            .onAppear { colour = Self.colour(hex) }
            .onChange(of: hex) { colour = Self.colour(hex) }
            .onChange(of: colour) {
                let next = Self.hex(colour)
                guard next != Self.hex(Self.colour(hex)) else { return }
                pending?.cancel()
                pending = Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    if !Task.isCancelled { onChange(next) }
                }
            }
    }

    static func colour(_ text: String) -> Color {
        let digits = text.dropFirst().prefix(6)
        guard text.hasPrefix("#"), digits.count == 6, let value = UInt32(digits, radix: 16) else { return .clear }
        return Color(hex: value)
    }

    static func hex(_ colour: Color) -> String {
        guard let rgb = NSColor(colour).usingColorSpace(.sRGB) else { return "" }
        let parts = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Int(($0 * 255).rounded()) }
        return "#" + parts.map { String(format: "%02X", $0) }.joined()
    }
}
