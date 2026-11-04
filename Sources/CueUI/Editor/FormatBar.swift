import SwiftUI

/// The small glass bar above text being edited on the slide: bold, italic,
/// underline, link and line break.
///
///     FormatBar { command in session.format(command) }
public struct FormatBar: View {
    public enum Command: String, CaseIterable, Sendable {
        case bold, italic, underline, link, lineBreak

        var symbol: String {
            switch self {
            case .bold: "bold"
            case .italic: "italic"
            case .underline: "underline"
            case .link: "link"
            case .lineBreak: "return"
            }
        }

        var help: String {
            switch self {
            case .bold: "Bold (⌘B)"
            case .italic: "Italic (⌘I)"
            case .underline: "Underline (⌘U)"
            case .link: "Link"
            case .lineBreak: "Line break (⇧↩)"
            }
        }
    }

    let action: (Command) -> Void

    public init(action: @escaping (Command) -> Void) {
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Command.allCases, id: \.self) { command in
                Button { action(command) } label: {
                    Image(systemName: command.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(command.help)
                .accessibilityLabel(command.help)
            }
        }
        .padding(.horizontal, 4)
        .foregroundStyle(CueTheme.text)
        .cueGlass(GlassPanelStyle(cornerRadius: 12))
    }
}

#Preview {
    FormatBar { _ in }.padding(40).background(CueBackground())
}
