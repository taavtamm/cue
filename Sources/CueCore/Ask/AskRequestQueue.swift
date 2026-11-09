import Foundation
import Observation

/// The Ask bar's requests, oldest first. The editor adds to it; the MCP
/// server takes from it (`next_request`) and marks requests done.
@MainActor @Observable
public final class AskRequestQueue {
    public private(set) var requests: [AskRequest] = []

    public init() {}

    /// Requests no session has finished or cancelled yet.
    public var open: [AskRequest] {
        requests.filter { $0.status == .waiting || $0.status == .inProgress }
    }

    /// Queues a request. Blank text is ignored and returns nil.
    @discardableResult
    public func enqueue(_ text: String, slide: Int, selection: ElementPath?) -> AskRequest? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = AskRequest(text: trimmed, slide: slide, selection: selection)
        requests.append(request)
        return request
    }

    /// The oldest waiting request, now marked in progress.
    public func takeNext() -> AskRequest? {
        guard let index = requests.firstIndex(where: { $0.status == .waiting }) else { return nil }
        requests[index].status = .inProgress
        return requests[index]
    }

    public func mark(_ id: UUID, _ status: AskRequest.Status, summary: String? = nil) {
        guard let index = requests.firstIndex(where: { $0.id == id }) else { return }
        requests[index].status = status
        if let summary { requests[index].summary = summary }
    }

    /// The most recent request, for the Ask bar's status line.
    public var latest: AskRequest? { requests.last }
}
