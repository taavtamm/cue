import CueCore
import CueMCP
import Foundation

/// A `DeckHost` over a plain document, like the app's but without windows.
actor FakeHost: DeckHost {
    private(set) var document: DeckDocument
    private(set) var ledger = ChangeSetLedger()
    nonisolated let mailbox = RequestMailbox()
    var decision: ClientApproval.Decision = .approved
    var selected: SelectionInfo?

    init(_ document: DeckDocument) { self.document = document }

    func setDecision(_ decision: ClientApproval.Decision) { self.decision = decision }
    func select(_ selection: SelectionInfo?) { selected = selection }

    func currentDocument() async -> DeckDocument? { document }
    func selection() async -> SelectionInfo? { selected }

    func apply(_ operations: [EditOperation], summary: String, client: String, slide: Int?) async throws -> ChangeSet {
        let original = document
        do {
            for operation in operations { try document.apply(operation) }
        } catch {
            document = original // All or nothing.
            throw error
        }
        guard let change = try ledger.record(from: original.source, to: document.source, client: client,
                                             summary: summary, slide: slide) else {
            throw CueMCPError.invalid("That didn't change anything.")
        }
        return change
    }

    func changes() async -> [ChangeSet] { ledger.changes }
    func accept(_ id: String) async throws { try ledger.accept(id) }

    func revert(_ id: String) async throws {
        let edit = try ledger.revertEdit(for: id)
        let result = try document.apply(.patches(edit))
        ledger.note(result.edit)
        ledger.markReverted(id)
    }

    func renderSlide(_ slide: Int, build: Int?) async throws -> Data { Data("png of slide \(slide)".utf8) }
    func approval(for client: String) async -> ClientApproval.Decision { decision }
}
