import CueEditor
import CueUI
import SwiftUI

/// What the selected element looks like, and the values you can change.
/// Every change is an inline-style patch on that element, with undo; the
/// deck's own stylesheet is never touched.
struct DesignInspector: View {
    @Bindable var session: EditorSession

    var body: some View {
        SnapshotFriendlyScrollView(axis: .vertical) {
            VStack(alignment: .leading, spacing: 18) {
                if let selection = session.selection {
                    header(selection)
                    typography(selection.values)
                    layout(selection.values)
                } else {
                    Text("Select something on the slide to see and change how it looks.")
                        .font(.system(size: 12))
                        .foregroundStyle(CueTheme.textSecondary)
                }
                liveContent
            }
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 16, trailing: 16))
            .font(.system(size: 12))
        }
    }

    private func header(_ selection: EditorSelection) -> some View {
        HStack(spacing: 10) {
            Text(selection.kind.badge)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(CueTheme.selectionText)
                .frame(width: 32, height: 32)
                .background(CueTheme.selection.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(selection.name.isEmpty ? selection.kind.title : selection.name)
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(sourceLine(selection)).font(.system(size: 11)).foregroundStyle(CueTheme.textTertiary).lineLimit(2)
            }
        }
    }

    private func sourceLine(_ selection: EditorSelection) -> String {
        selection.values.source.isEmpty ? selection.kind.title : "\(selection.kind.title) · \(selection.values.source)"
    }

    private func typography(_ values: InspectorValues) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Typography")
            HStack {
                Text(values.fontFamily.isEmpty ? "—" : values.fontFamily)
                Spacer()
                Text(values.fontWeight).foregroundStyle(CueTheme.textTertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            HStack(spacing: 6) {
                field("Size", values.fontSize, .fontSize)
                field("Line", values.lineHeight, .lineHeight)
                field("Track", values.tracking, .tracking)
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6).fill(Self.swatch(values.color)).frame(width: 22, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.2)))
                let hex = values.color.components(separatedBy: " · ").first ?? ""
                InspectorField("Colour", value: hex, placement: .leading) { input in
                    Task { await session.setStyle(.color, to: input) }
                }
            }
            if let variable = values.colorVariable {
                Text("from \(variable)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CueTheme.textTertiary)
            }
        }
    }

    private func layout(_ values: InspectorValues) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Layout")
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    InspectorField("X", value: values.x, placement: .leading, isEditable: false)
                    InspectorField("Y", value: values.y, placement: .leading, isEditable: false)
                }
                GridRow {
                    field("W", values.width, .width, placement: .leading)
                    field("H", values.height, .height, placement: .leading)
                }
            }
            Text("Position comes from the deck's layout; width and height set inline sizes.")
                .font(.system(size: 10.5)).foregroundStyle(CueTheme.textTertiary)
        }
    }

    private var liveContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Live content")
            Toggle("Play live content in editor", isOn: Binding(
                get: { session.isPlayingLive }, set: { session.setPlayingLive($0) }
            ))
            .toggleStyle(.cue)
            if session.liveSlides.contains(session.slide) {
                Text("This slide has live web content. Double-click it to try it; ⌘-click to select.")
                    .font(.system(size: 11)).foregroundStyle(CueTheme.textTertiary)
            }
        }
    }

    private func field(_ label: String, _ value: String, _ kind: StyleInput.Field,
                       placement: InspectorField.LabelPlacement = .above) -> some View {
        InspectorField(label, value: value, placement: placement) { input in
            Task { await session.setStyle(kind, to: input) }
        }
    }

    /// The swatch colour for "#RRGGBB" (alpha shown in text, not here).
    private static func swatch(_ text: String) -> Color {
        let hex = text.dropFirst().prefix(6)
        guard text.hasPrefix("#"), hex.count == 6, let value = UInt32(hex, radix: 16) else { return .clear }
        return Color(hex: value)
    }
}
