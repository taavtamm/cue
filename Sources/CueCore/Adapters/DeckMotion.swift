import Foundation

/// The `<script type="application/json" id="deck-motion">` block Claude Design
/// writes: per-slide build steps and live embeds. Only the fields Cue reads.
struct DeckMotion: Decodable {
    struct Slide: Decodable {
        let steps: [Step]
        let embeds: [Embed]?
    }
    struct Step: Decodable {
        let events: [Event]?
    }
    struct Event: Decodable {
        let id: String
        let effect: String?
        let dir: String?
    }
    struct Embed: Decodable {
        let id: String
    }

    let slides: [Slide]

    /// Steps after the first become builds; step 0 is the slide's initial state.
    func builds(forSlide index: Int) -> [BuildStep] {
        guard slides.indices.contains(index) else { return [] }
        return slides[index].steps.dropFirst().map { step in
            let events = step.events ?? []
            return BuildStep(
                targets: events.map { "[data-frame-id=\"\($0.id)\"]" },
                effect: events.first?.effect
            )
        }
    }

    func hasEmbeds(slide index: Int) -> Bool? {
        guard slides.indices.contains(index) else { return nil }
        return !(slides[index].embeds ?? []).isEmpty
    }
}
