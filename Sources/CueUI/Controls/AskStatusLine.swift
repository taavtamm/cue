import SwiftUI

/// The line under the Ask bar: what the agent is doing right now, in plain
/// words, with an animated dot while it works and an optional button
/// (Connect, Undo).
public struct AskStatusLine: View {
    public enum Tone: Sendable, Equatable { case offline, idle, listening, working, editing, done }

    let text: String
    let tone: Tone
    let action: (title: String, run: () -> Void)?

    public init(_ text: String, tone: Tone, action: (title: String, run: () -> Void)? = nil) {
        self.text = text
        self.tone = tone
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 7) {
            indicator
            Text(text).lineLimit(1).truncationMode(.middle)
            if let action {
                Button(action.title, action: action.run).buttonStyle(.cue(height: 22))
            }
        }
        .font(.system(size: 11.5))
        .foregroundStyle(tone == .offline ? CueTheme.textTertiary : CueTheme.textSecondary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var indicator: some View {
        switch tone {
        case .offline: Circle().fill(CueTheme.textTertiary.opacity(0.6)).frame(width: 7, height: 7)
        case .idle: Circle().fill(CueTheme.successBright.opacity(0.8)).frame(width: 7, height: 7)
        case .listening: PulsingDot(CueTheme.successBright, diameter: 7)
        case .working: PulsingDot(CueTheme.live, diameter: 7)
        case .editing: PulsingDot(CueTheme.violet, diameter: 8)
        case .done: Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(CueTheme.successBright)
        }
    }
}
