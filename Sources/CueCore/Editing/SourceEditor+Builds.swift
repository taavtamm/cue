import Foundation

extension SourceEditor {
    /// Writes the build order where the deck's player reads it: the
    /// deck-motion JSON for Claude Design, `data-cue-build` attributes otherwise.
    func setBuilds(slide index: Int, steps: [BuildSpec]) throws -> SourceEdit {
        let slide = try slideElement(index)
        let targets = try steps.map { step in
            try step.targets.map { path -> MappedElement in
                guard path.starts(with: slide.path), path != slide.path else {
                    throw EditError.unsupported("a build target outside slide \(index + 1)")
                }
                return try element(path)
            }
        }
        switch structure.adapter {
        case .claudeDesign:
            return try claudeDesignBuilds(slide: index, steps: steps, targets: targets)
        case .reveal:
            throw EditError.unsupported("builds in reveal.js decks (reveal drives its own fragments)")
        default:
            return try cueBuilds(slide: slide, steps: steps, targets: targets)
        }
    }

    /// `data-cue-build="n"` (1-based) and `data-cue-effect` on each target;
    /// removed from elements that are no longer built.
    private func cueBuilds(slide: MappedElement, steps: [BuildSpec], targets: [[MappedElement]]) throws -> SourceEdit {
        var wanted: [ElementPath: (build: String, effect: String?)] = [:]
        for (number, step) in steps.enumerated() {
            for target in targets[number] { wanted[target.path] = (String(number + 1), step.effect) }
        }
        var patches: [SourcePatch] = []
        for element in map.elements where element.path.starts(with: slide.path) && element.path != slide.path {
            let want = wanted[element.path]
            var changes: [(String, String?)] = []
            if element.attributes["data-cue-build"] != want?.build { changes.append(("data-cue-build", want?.build)) }
            if element.attributes["data-cue-effect"] != want?.effect {
                changes.append(("data-cue-effect", want?.effect))
            }
            if !changes.isEmpty { patches += try attributePatches(on: element, changes) }
        }
        return SourceEdit(patches)
    }

    /// Replaces `slides[n].steps` in the deck-motion JSON. Step 0 hides every
    /// built element; step k reveals step k's elements.
    private func claudeDesignBuilds(
        slide index: Int, steps: [BuildSpec], targets: [[MappedElement]]
    ) throws -> SourceEdit {
        guard let motion = try DeckMotionPatches(editor: self) else {
            throw EditError.malformedSource("no deck-motion block")
        }
        let ids = try targets.map { step in
            try step.map { element in
                guard let id = element.attributes["data-frame-id"] else {
                    throw EditError.unsupported("a build target without data-frame-id")
                }
                return id
            }
        }
        var json: [MotionStep] = [MotionStep(hidden: ids.flatMap { $0 }, events: [])]
        for (number, stepIDs) in ids.enumerated() {
            let later = ids.dropFirst(number + 1).flatMap { $0 }
            let effect = steps[number].effect ?? "fade"
            let events = stepIDs.map { MotionEvent(id: $0, effect: effect, dir: "in") }
            json.append(MotionStep(hidden: later, events: events))
        }
        let text = try escaping.verbatim(ScriptSafeJSON.encode(json))
        return SourceEdit([try motion.replaceSteps(ofSlide: index, with: text)])
    }
}

/// One step of deck-motion JSON, as Claude Design writes it.
private struct MotionStep: Encodable {
    let hidden: [String]
    let events: [MotionEvent]
    var auto = false
}

private struct MotionEvent: Encodable {
    let id: String
    let effect: String
    let dir: String
}
