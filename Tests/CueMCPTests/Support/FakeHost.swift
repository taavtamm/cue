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

    var loads: [Int: SlideLoad] = [:]
    func setLoads(_ loads: [Int: SlideLoad]) { self.loads = loads }
    func performance(of slides: [Int]) async throws -> (loads: [Int: SlideLoad], live: Set<Int>) {
        (loads.filter { slides.contains($0.key) }, [0])
    }

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

    /// Tool calls the server reported, in order: "start get_outline", "finish edit_element failed".
    private(set) var activityLog: [String] = []
    private(set) var activities: [ToolActivity] = []
    /// Image downloads go through this (a stubbed session in tests).
    var downloader = ImageDownloader()
    func setDownloader(_ downloader: ImageDownloader) { self.downloader = downloader }

    func fetchImage(_ url: URL) async throws -> Data { try await downloader.fetch(url) }
    func toolDidStart(_ activity: ToolActivity) async {
        activities.append(activity)
        activityLog.append("start \(activity.tool)")
    }
    func toolDidFinish(_ activity: ToolActivity, failed: Bool) async {
        activityLog.append("finish \(activity.tool)\(failed ? " failed" : "")")
    }
    func approval(for client: String) async -> ClientApproval.Decision { decision }

    // Decks, in a temporary folder that stands in for the user's home.
    let root = FileManager.default.temporaryDirectory.appending(path: "cue-fake-home-\(UUID().uuidString)")
    private(set) var targetURL: URL?
    private(set) var saved = 0

    func deckRoot() async -> URL { root }
    func newDeckFolder() async -> URL { root.appending(path: "Documents/Cue Decks") }

    func decks() async -> [DeckSummary] { [summary(document)] }

    func createDeck(at url: URL, title: String, html: String?) async throws -> DeckSummary {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data((html ?? BlankDeckTemplate.html(title: title)).utf8).write(to: url)
        return try await openDeck(url)
    }

    func openDeck(_ url: URL) async throws -> DeckSummary {
        let opened = try DeckDocument(contentsOf: url)
        document = opened
        targetURL = url
        ledger = ChangeSetLedger()
        return summary(opened)
    }

    func saveDeck() async throws -> DeckSummary {
        try document.save()
        saved += 1
        return summary(document)
    }

    private func summary(_ document: DeckDocument) -> DeckSummary {
        DeckSummary(path: document.fileURL.path, title: document.fileURL.deletingPathExtension().lastPathComponent,
                    slides: document.structure.slides.count, isOpen: true, isTarget: true, hasUnsavedChanges: document.isDirty)
    }
}
