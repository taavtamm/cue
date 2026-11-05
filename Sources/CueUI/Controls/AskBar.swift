import SwiftUI

/// The Siri-style "Ask Cue to change this slide…" bar under the slide:
/// glowing ring, orb, glowing-caret field, suggestion chips and a mic.
public struct AskBar: View {
    @Binding var text: String
    var placeholder = "Ask Cue to change this slide…"
    var suggestions: [String] = []
    let onSubmit: () -> Void
    var onSuggestion: (String) -> Void = { _ in }
    var onDictate: () -> Void = {}
    var activity: AskBarActivity = .idle
    /// A button in the bar for the current status, e.g. Connect… or Undo.
    var action: (title: String, run: () -> Void)?
    /// False: a status bar only (the user talks to their agent elsewhere):
    /// the placeholder is shown as text, with no field, suggestions or mic.
    var acceptsInput = true
    @Environment(\.cueRendersStatically) private var rendersStatically

    public init(
        text: Binding<String>,
        placeholder: String = "Ask Cue to change this slide…",
        suggestions: [String] = [],
        onSubmit: @escaping () -> Void,
        onSuggestion: @escaping (String) -> Void = { _ in },
        onDictate: @escaping () -> Void = {},
        activity: AskBarActivity = .idle,
        action: (title: String, run: () -> Void)? = nil,
        acceptsInput: Bool = true
    ) {
        self.activity = activity
        self.action = action
        self.acceptsInput = acceptsInput
        self._text = text
        self.placeholder = placeholder
        self.suggestions = suggestions
        self.onSubmit = onSubmit
        self.onSuggestion = onSuggestion
        self.onDictate = onDictate
    }

    public var body: some View {
        HStack(spacing: 10) {
            AskOrb(breathes: !activity.glowIsStill)
            field
                .frame(height: 40)
                .frame(maxWidth: .infinity)
            if let action {
                SuggestionChip(action.title, action: action.run)
            } else if acceptsInput {
                ForEach(suggestions, id: \.self) { suggestion in
                    SuggestionChip(suggestion) { onSuggestion(suggestion) }
                }
            }
            if acceptsInput {
                IconButton("Dictate", systemImage: "mic", size: 38, iconSize: 18, action: onDictate)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: 58)
        .background(Color(red: 14 / 255, green: 14 / 255, blue: 18 / 255, opacity: 0.95), in: Capsule())
        .overlay { if activity.shimmers { AskBarShimmer() } }
        .siriGlow(Capsule().inset(by: -1), ringWidth: 1.5, haloBlur: 16, haloOpacity: activity.haloOpacity,
                  speed: activity.glowSpeed, isPaused: activity.glowIsStill)
        .animation(.easeInOut(duration: 0.3), value: activity)
    }

    @ViewBuilder private var field: some View {
        if !acceptsInput {
            Text(placeholder)
                .font(.system(size: 15))
                .foregroundStyle(activity == .offline ? Color.white.opacity(0.55) : CueTheme.text.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: placeholder)
                .accessibilityLabel("Agent status: \(placeholder)")
        } else if rendersStatically {
            Text(text.isEmpty ? placeholder : text)
                .font(.system(size: 16))
                .foregroundStyle(text.isEmpty ? Color.white.opacity(0.62) : CueTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            GlowTextField(placeholder, text: $text, style: .ask, onSubmit: onSubmit)
        }
    }
}

#Preview {
    @Previewable @State var ask = ""
    AskBar(text: $ask, suggestions: ["Build the cards one by one", "Tighten headline"]) {}
        .frame(width: 780)
        .padding(40)
        .background(CueBackground())
}
