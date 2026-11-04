import CueCore
import CueEditor
import CueUI
import SwiftUI

/// Fill, border, corner radius, opacity and shadow of the selected box,
/// image or shape, as inline styles.
struct AppearanceInspector: View {
    let session: EditorSession
    let values: InspectorValues

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Appearance")
            HStack(spacing: 6) {
                ColourWell(hex: values.fill) { set("background-color", $0) }
                InspectorField("Fill", value: values.fill, placement: .leading) { input in
                    set("background-color", Self.colour(input))
                }
            }
            HStack(spacing: 6) {
                ColourWell(hex: values.borderColor) { colour in setBorder(colour: colour) }
                InspectorField("Border", value: values.borderWidth, placement: .leading) { input in
                    guard let width = Double(input.replacingOccurrences(of: "px", with: "")) else { return }
                    setBorder(width: width)
                }
            }
            HStack(spacing: 6) {
                InspectorField("Radius", value: values.cornerRadius, placement: .leading) { input in
                    guard let radius = Double(input.replacingOccurrences(of: "px", with: "")) else { return }
                    set("border-radius", "\(Int(radius))px")
                }
                InspectorField("Opacity", value: values.opacity, placement: .leading) { input in
                    guard let percent = Double(input.replacingOccurrences(of: "%", with: "")) else { return }
                    set("opacity", InspectorValuesFormat.number(min(100, max(0, percent)) / 100))
                }
            }
            Toggle("Shadow", isOn: Binding(get: { values.hasShadow }, set: { on in
                set("box-shadow", on ? "0 24px 48px rgba(0, 0, 0, 0.28)" : nil)
            }))
            .toggleStyle(.cue)
            HStack(spacing: 6) {
                Button("Bring Forward") { Task { await session.restack(by: 1) } }
                Button("Send Backward") { Task { await session.restack(by: -1) } }
            }
            .buttonStyle(.cue(height: 28))
        }
    }

    private func set(_ property: String, _ value: String?) {
        guard let path = session.selection?.path else { return }
        if let value, value.isEmpty { return }
        Task { await session.apply(.setStyle(path, property: property, value: value)) }
    }

    private func setBorder(colour: String? = nil, width: Double? = nil) {
        guard let path = session.selection?.path else { return }
        let colour = colour ?? (values.borderColor.hasPrefix("#") ? values.borderColor : "#FFFFFF")
        let width = width ?? max(1, Double(values.borderWidth) ?? 0)
        let value = width <= 0 ? nil : "\(Int(width))px solid \(colour)"
        Task { await session.apply(.setStyles(path, [StyleChange("border", value)])) }
    }

    /// "none" clears the fill; hex and rgb() pass through.
    private static func colour(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespaces)
        if text.lowercased() == "none" { return "transparent" }
        return StyleInput.cssValue(text, for: .color) ?? ""
    }
}

/// Number formatting shared with the inspector model.
enum InspectorValuesFormat {
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
