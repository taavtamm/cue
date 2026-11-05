import Foundation

/// Answers image downloads in tests without a network: register bodies by URL.
final class StubImageServer: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [String: (status: Int, type: String, body: Data)] = [:]

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubImageServer.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let key = request.url?.absoluteString ?? ""
        guard let stub = Self.responses[key], let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": stub.type])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
