import SwiftUI

/// A compact segmented control on a dark track, like the editor's
/// Design / HTML / Outline switch and the inspector tabs.
///
///     SegmentedSwitch(selection: $mode, options: EditorMode.allCases) { $0.title }
public struct SegmentedSwitch<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    var fillsWidth = false

    public init(
        selection: Binding<Option>,
        options: [Option],
        fillsWidth: Bool = false,
        title: @escaping (Option) -> String
    ) {
        self._selection = selection
        self.options = options
        self.fillsWidth = fillsWidth
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                segment(option)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.06))
        )
        .accessibilityElement(children: .contain)
    }

    private func segment(_ option: Option) -> some View {
        let isOn = option == selection
        return Button {
            selection = option
        } label: {
            Text(title(option))
                .font(.system(size: 12.5, weight: isOn ? .semibold : .medium))
                .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.7))
                .padding(.horizontal, 14)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(height: 28)
                .background {
                    if isOn {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(CueTheme.controlSelected)
                            .shadow(color: .white.opacity(0.18), radius: 0, y: -0.5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}

#Preview {
    @Previewable @State var mode = "Design"
    SegmentedSwitch(selection: $mode, options: ["Design", "HTML", "Outline"]) { $0 }
        .padding(24)
        .background(CueTheme.ground)
}
