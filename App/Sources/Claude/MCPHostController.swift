import AppKit
import CueCore
import CueEditor
import CueMCP
import Foundation

/// Cue's MCP server works on the deck in the front-most editor window. Every
/// call hops to the main actor, where the editor lives, so Claude's edits go
/// through the same live, undoable path as the user's.
final class MCPHostController: DeckHost, @unchecked Sendable {
    let mailbox: RequestMailbox
    private let approvals: ClientApproval
    private let frontSession: @MainActor @Sendable () -> EditorSession?
    private let askUser: @MainActor @Sendable (String) -> Void
    @MainActor private lazy var snapshotter = SlideSnapshotter()

    init(mailbox: RequestMailbox, approvals: ClientApproval,
         frontSession: @escaping @MainActor @Sendable () -> EditorSession?,
         askUser: @escaping @MainActor @Sendable (String) -> Void) {
        self.mailbox = mailbox
        self.approvals = approvals
        self.frontSession = frontSession
        self.askUser = askUser
    }

    func currentDocument() async -> DeckDocument? { await MainActor.run { frontSession()?.document } }

    func selection() async -> SelectionInfo? { await MainActor.run { Self.selection(in: frontSession()) } }

    func apply(_ operations: [EditOperation], summary: String, client: String, slide: Int?) async throws -> ChangeSet {
        try await applyOnMain(operations, summary: summary, client: client, slide: slide)
    }

    func apply(_ operations: [EditOperation], summary: String, client: String, slide: Int?,
               plannedOn source: String) async throws -> ChangeSet {
        try await applyOnMain(operations, summary: summary, client: client, slide: slide, plannedOn: source)
    }

    func changes() async -> [ChangeSet] { await MainActor.run { frontSession()?.claudeChanges.all ?? [] } }

    func accept(_ id: String) async throws { try await acceptOnMain(id) }

    func revert(_ id: String) async throws { try await revertOnMain(id) }

    func renderSlide(_ slide: Int, build: Int?) async throws -> Data { try await renderOnMain(slide, build: build) }

    func approval(for client: String) async -> ClientApproval.Decision {
        let decision = approvals.decision(for: client)
        if decision == .pending { await MainActor.run { askUser(client) } }
        return decision
    }

    // MARK: On the main actor

    @MainActor private func session() throws -> EditorSession {
        guard let session = frontSession() else { throw CueMCPError.noDeck }
        return session
    }

    @MainActor private func applyOnMain(_ operations: [EditOperation], summary: String, client: String,
                                        slide: Int?, plannedOn source: String? = nil) async throws -> ChangeSet {
        let session = try session()
        // Checked and applied in one main-actor step, on the same session.
        if let source, session.document.source != source { throw CueMCPError.deckChanged }
        return try await session.applyClaudeChange(operations, summary: summary, client: client, slide: slide,
                                              autoAccept: CueSettings.shared.autoAcceptClaudeEdits)
    }

    @MainActor private func acceptOnMain(_ id: String) async throws { try session().acceptClaudeChange(id) }

    @MainActor private func revertOnMain(_ id: String) async throws { try await session().revertClaudeChange(id) }

    @MainActor private func renderOnMain(_ slide: Int, build: Int?) async throws -> Data {
        try await snapshotter.png(of: session().document, slide: slide, build: build)
    }

    @MainActor static func selection(in session: EditorSession?) -> SelectionInfo? {
        guard let session, let selection = session.selection else { return nil }
        let document = session.document
        let startTag = selection.element.startTag.map {
            (document.source as NSString).substring(with: NSRange(location: $0.start, length: $0.length))
        }
        return SelectionInfo(
            slide: session.slide + 1, cueID: selection.cueID, path: selection.path, tag: selection.element.tag,
            label: selection.name.isEmpty ? nil : selection.name, startTag: startTag,
            computedStyle: selection.inspection?.computedStyle ?? [:]
        )
    }
}
