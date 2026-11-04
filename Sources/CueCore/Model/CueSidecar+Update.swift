import Foundation

extension CueSidecar {
    /// Loads the sidecar, applies `change`, and saves it, so separate parts of
    /// Cue (display roles, network choices) never overwrite each other's keys.
    public static func update(at url: URL, _ change: (inout CueSidecar) -> Void) throws {
        var sidecar = try load(from: url)
        change(&sidecar)
        try sidecar.save(to: url)
    }
}
