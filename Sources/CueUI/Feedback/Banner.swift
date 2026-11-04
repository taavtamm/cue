import SwiftUI

/// A non-modal glass strip that asks one question or states one fact, with
/// up to three buttons. Cue never uses browser dialogs; this is the
/// replacement, e.g. "This deck loads fonts from fonts.gstatic.com. Allow?"
///
///     Banner(systemImage: "network", message: request.message, actions: [
///         .init("Allow", kind: .primary) { allow() },
///         .init("Not now") { dismiss() },
///     ])
public struct Banner: View {
    public struct Action: Identifiable {
        public let id = UUID()
        let title: String
        let kind: CueButtonStyle.Kind
        let run: () -> Void

        public init(_ title: String, kind: CueButtonStyle.Kind = .glass, run: @escaping () -> Void) {
            self.title = title
            self.kind = kind
            self.run = run
        }
    }

    let systemImage: String
    let message: String
    let detail: String?
    let actions: [Action]

    public init(systemImage: String, message: String, detail: String? = nil, actions: [Action]) {
        self.systemImage = systemImage
        self.message = message
        self.detail = detail
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(CueTheme.liveText)
                .frame(width: 30, height: 30)
                .background(CueTheme.live.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(message).font(.system(size: 13, weight: .semibold))
                if let detail {
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(CueTheme.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            ForEach(actions) { action in
                Button(action.title, action: action.run).buttonStyle(.cue(action.kind, height: 30))
            }
        }
        .foregroundStyle(CueTheme.text)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .cueGlass(GlassPanelStyle(cornerRadius: CueTheme.panelRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message)
    }
}

#Preview {
    Banner(
        systemImage: "network",
        message: "This deck loads fonts from fonts.googleapis.com and fonts.gstatic.com.",
        detail: "Cue blocks the network until you allow it. Your choice is saved with the deck.",
        actions: [.init("Allow", kind: .primary) {}, .init("Not now") {}]
    )
    .padding(24)
    .frame(width: 760)
    .background(CueBackground())
}
