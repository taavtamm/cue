import Foundation

/// Requests typed into Cue's Ask bar, waiting for a Claude session to take
/// them with `next_request`. A session that calls `next_request` waits here
/// (long poll) until something arrives or the timeout passes.
public actor RequestMailbox {
    public struct Request: Sendable, Codable, Equatable, Identifiable {
        public enum Status: String, Sendable, Codable { case waiting, working, done, cancelled }

        public let id: String
        public let text: String
        /// 1-based slide the user was on.
        public let slide: Int
        /// The selected element's path, if something was selected.
        public let selection: [Int]?
        public internal(set) var status: Status
        public internal(set) var summary: String?
    }

    private var requests: [Request] = []
    private var waiters: [UUID: CheckedContinuation<Request?, Never>] = [:]
    private var counter = 0
    /// When a session last asked for work: "is Claude listening?" for the UI.
    public private(set) var lastPoll: Date?
    private var onChange: (@Sendable (Request) -> Void)?

    public init() {}

    /// Called with each request whenever its status changes (UI updates).
    public func observe(_ handler: @escaping @Sendable (Request) -> Void) { onChange = handler }

    /// True while a session is waiting in `next_request` right now.
    public var isListening: Bool { !waiters.isEmpty }

    @discardableResult
    public func post(_ text: String, slide: Int, selection: [Int]?) -> Request {
        counter += 1
        let request = Request(id: "ask-\(counter)", text: text, slide: slide, selection: selection,
                              status: .waiting, summary: nil)
        requests.append(request)
        onChange?(request)
        if let (key, waiter) = waiters.first {
            waiters[key] = nil
            waiter.resume(returning: take(request.id))
        }
        return request
    }

    /// The oldest waiting request (now marked working), waiting up to `timeout` for one.
    public func next(timeout: Duration) async -> Request? {
        lastPoll = Date()
        if let waiting = requests.first(where: { $0.status == .waiting }) { return take(waiting.id) }
        let key = UUID()
        return await withCheckedContinuation { continuation in
            waiters[key] = continuation
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                await self?.expire(key)
            }
        }
    }

    public func complete(_ id: String, summary: String?) throws {
        guard let index = requests.firstIndex(where: { $0.id == id }) else {
            throw CueMCPError.invalid("There's no Ask request \(id).")
        }
        requests[index].status = .done
        requests[index].summary = summary
        onChange?(requests[index])
    }

    public func cancel(_ id: String) {
        guard let index = requests.firstIndex(where: { $0.id == id }), requests[index].status != .done else { return }
        requests[index].status = .cancelled
        onChange?(requests[index])
    }

    public func request(_ id: String) -> Request? { requests.first { $0.id == id } }

    private func take(_ id: String) -> Request? {
        guard let index = requests.firstIndex(where: { $0.id == id }) else { return nil }
        requests[index].status = .working
        onChange?(requests[index])
        return requests[index]
    }

    private func expire(_ key: UUID) {
        waiters.removeValue(forKey: key)?.resume(returning: nil)
    }
}
