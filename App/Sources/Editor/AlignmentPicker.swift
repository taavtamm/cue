import CueEditor
import CueUI
import SwiftUI

/// Left, centre, right and justified text, as inline `text-align`.
struct AlignmentPicker: View {
    let session: EditorSession
    let current: String

    private static let options: [(value: String, symbol: String, name: String)] = [
        ("left", "text.alignleft", "Align left"), ("center", "text.aligncenter", "Centre"),
        ("right", "text.alignright", "Align right"), ("justify", "text.justify", "Justify"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.options, id: \.value) { option in
                let on = current == option.value || (option.value == "left" && current == "start")
                Button {
                    guard let path = session.selection?.path else { return }
                    Task { await session.apply(.setStyle(path, property: "text-align", value: option.value)) }
                } label: {
                    Image(systemName: option.symbol).frame(maxWidth: .infinity, minHeight: 26)
                        .background(on ? Color.white.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(option.name)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }
}
