import Foundation

/// What an edit did: the patches, whether slides or builds changed, and how
/// open surfaces should catch up.
public struct EditResult: Sendable, Equatable {
    public let edit: SourceEdit
    public let structureChanged: Bool
    public let live: LiveUpdate

    public static let none = EditResult(edit: SourceEdit([]), structureChanged: false, live: .none)
}
