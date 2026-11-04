import SwiftUI

/// A small labelled value in the inspector. Typing doesn't change the deck
/// until Return or leaving the field, so half-typed values never reach it.
///
///     InspectorField("Size", value: values.fontSize) { session.setStyle(.fontSize, to: $0) }
public struct InspectorField: View {
    public enum LabelPlacement: Sendable { case above, leading }

    let label: String
    let value: String
    let placement: LabelPlacement
    let isEditable: Bool
    let onCommit: (String) -> Void
    @State private var text = ""
    @Environment(\.cueRendersStatically) private var rendersStatically

    public init(_ label: String, value: String, placement: LabelPlacement = .above, isEditable: Bool = true,
                onCommit: @escaping (String) -> Void = { _ in }) {
        self.label = label
        self.value = value
        self.placement = placement
        self.isEditable = isEditable
        self.onCommit = onCommit
    }

    public var body: some View {
        Group {
            switch placement {
            case .above:
                VStack(alignment: .leading, spacing: 4) {
                    caption
                    field.padding(.horizontal, 8).frame(height: 30).background(fieldBackground)
                }
            case .leading:
                HStack(spacing: 8) {
                    caption
                    field
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(fieldBackground)
            }
        }
        .onAppear { text = value }
        .onChange(of: value) { text = value }
    }

    private var caption: some View {
        Text(label).font(.system(size: 10.5)).foregroundStyle(CueTheme.textTertiary)
    }

    @ViewBuilder private var field: some View {
        if rendersStatically {
            Text(value).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            editableField
        }
    }

    private var editableField: some View {
        GlowTextField(
            label, text: $text, style: .compact, isEditable: isEditable, onSubmit: commit, onEndEditing: commit
        )
            .frame(height: 18)
            .opacity(isEditable ? 1 : 0.7)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }

    private func commit() {
        guard isEditable, text != value else { return }
        onCommit(text)
    }
}

#Preview {
    HStack {
        InspectorField("Size", value: "88")
        InspectorField("Line", value: "1.04")
        InspectorField("X", value: "128", placement: .leading)
    }
    .frame(width: 280)
    .padding()
    .background(CueTheme.ground)
}
