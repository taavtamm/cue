import Foundation

/// Reads the click sequence from `p:timing` into build steps. Each click
/// in the main sequence is one step; entrance effects in it reveal their
/// shapes. Emphasis and exit effects are reported, not imported.
enum PptxTiming {
    static func builds(in slide: XNode, _ context: PptxContext) -> [String: (step: Int, effect: String)] {
        guard let timing = slide.child("timing"),
              let sequence = timing.descendants.first(where: { $0.name == "cTn" && $0["nodeType"] == "mainSeq" }),
              let clicks = sequence.child("childTnLst")?.children("par") else { return [:] }
        var result: [String: (step: Int, effect: String)] = [:]
        var step = 0
        for click in clicks {
            let effects = click.descendants.filter { $0.name == "cTn" && $0["presetClass"] != nil }
            let entrances = effects.filter { $0["presetClass"] == "entr" }
            if effects.count > entrances.count { context.note("Emphasis and exit animations aren't imported") }
            guard !entrances.isEmpty else { continue }
            step += 1
            for effect in entrances {
                let name = effect["presetID"] == "1" ? "appear" : "fade"
                if !["1", "10"].contains(effect["presetID"] ?? "") { context.note("Entrance animations play as fades") }
                for target in effect.descendants where target.name == "spTgt" {
                    if let id = target["spid"], result[id] == nil { result[id] = (step, name) }
                }
            }
        }
        return result
    }
}
