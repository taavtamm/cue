import Foundation

extension CueSidecar {
    /// Loads the sidecar, applies `change`, and saves it, so separate parts of
    /// Cue (display roles, rehearsal timings) never overwrite each other's keys.
    ///
    /// A sidecar that can't be read is never replaced: the error is thrown and
    /// the file stays as it is. Keys this version of Cue doesn't know (a newer
    /// Cue, a hand edit) are kept.
    public static func update(at url: URL, _ change: (inout CueSidecar) -> Void) throws {
        var sidecar = try load(from: url)
        change(&sidecar)
        try sidecar.save(to: url, keepingUnknownKeysFrom: url)
    }

    /// Saves, keeping any top-level keys in the existing file that this
    /// version doesn't model.
    func save(to url: URL, keepingUnknownKeysFrom existing: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let known = try encoder.encode(self)
        guard let old = try? Data(contentsOf: existing),
              let oldObject = try? JSONSerialization.jsonObject(with: old) as? [String: Any],
              let newObject = try JSONSerialization.jsonObject(with: known) as? [String: Any]
        else { return try known.write(to: url, options: .atomic) }
        let merged = oldObject.merging(newObject) { _, new in new }
        let data = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }
}
