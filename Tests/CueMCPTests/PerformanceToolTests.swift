import CueCore
import Foundation
import MCP
import Testing
@testable import CueMCP

@Suite("get_performance")
struct PerformanceToolTests {
    @Test func reportsEachSlideWithItsVerdict() async throws {
        let (document, _) = try Decks.document()
        let host = FakeHost(document)
        await host.setLoads([
            0: SlideLoad(blurs: 6, loopingAnimations: 9, embeds: 0, redrawsPerSecond: 60),
            1: SlideLoad(blurs: 0, loopingAnimations: 0, embeds: 0, redrawsPerSecond: 0),
        ])
        let harness = try await MCPHarness.connect(host)
        let reply = try await harness.call("get_performance", ["slides": [1, 2]])
        #expect(!reply.isError, "\(reply.text)")
        let object = try #require(try JSONSerialization.jsonObject(with: Data(reply.text.utf8)) as? [String: Any])
        #expect(object["heavy"] as? Bool == true)
        let slides = try #require(object["slides"] as? [[String: Any]])
        #expect(slides.count == 2)
        #expect(slides[0]["slide"] as? Int == 1 && slides[0]["heavy"] as? Bool == true)
        #expect(slides[0]["measured_live"] as? Bool == true && slides[1]["measured_live"] as? Bool == false)
        #expect((slides[0]["reasons"] as? [String])?.contains("scripts redrawing every frame") == true)
        #expect(slides[1]["heavy"] as? Bool == false)
        let outOfRange = try await harness.call("get_performance", ["slides": [99]])
        #expect(outOfRange.isError)
    }
}
