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

    public init(
        text: Binding<String>,
        placeholder: String = "Ask Cue to change this slide…",
        suggestions: [String] = [],
        onSubmit: @escaping () -> Void,
        onSuggestion: @escaping (String) -> Void = { _ in },
        onDictate: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.suggestions = suggestions
        self.onSubmit = onSubmit
        self.onSuggestion = onSuggestion
        self.onDictate = onDictate
    }

    public var body: some View {
        HStack(spacing: 10) {
            AskOrb()
            GlowTextField(placeholder, text: $text, style: .ask, onSubmit: onSubmit)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
            ForEach(suggestions, id: \.self) { suggestion in
                SuggestionChip(suggestion) { onSuggestion(suggestion) }
            }
            IconButton("Dictate", systemImage: "mic", size: 38, iconSize: 18, action: onDictate)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: 58)
        .background(Color(red: 14 / 255, green: 14 / 255, blue: 18 / 255, opacity: 0.95), in: Capsule())
        .siriGlow(Capsule().inset(by: -1), ringWidth: 1.5, haloBlur: 16, haloOpacity: 0.55)
    }
}

#Preview {
    @Previewable @State var ask = ""
    AskBar(text: $ask, suggestions: ["Build the cards one by one", "Tighten headline"]) {}
        .frame(width: 780)
        .padding(40)
        .background(CueBackground())
}
