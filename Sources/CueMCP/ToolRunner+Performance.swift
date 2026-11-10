import CueCore
import Foundation
import MCP

/// `get_performance`: what keeps the GPU busy, slide by slide.
extension ToolRunner {
    func performance(_ args: ToolArguments) async throws -> CallTool.Result {
        let count = try await document().structure.slides.count
        var numbers = (args.array("slides") ?? []).compactMap { $0.intValue }
        if numbers.isEmpty { numbers = Array(1...max(1, count)) }
        guard numbers.allSatisfy({ (1...count).contains($0) }) else { throw CueMCPError.invalid("Slides are 1–\(count).") }
        let (loads, live) = try await host.performance(of: numbers.map { $0 - 1 })
        let slides = numbers.compactMap { number in
            loads[number - 1].map { SlidePerformance(slide: number, load: $0, measuredLive: live.contains(number - 1)) }
        }
        return try json(PerformanceReport(heavy: DeckLoadReport(loads).isHeavy, slides: slides))
    }
}

/// `get_performance`'s reply.
struct PerformanceReport: Encodable {
    let heavy: Bool
    let slides: [SlidePerformance]
}

struct SlidePerformance: Encodable {
    let slide: Int
    let blurs: Int
    let loopingAnimations: Int
    let embeds: Int
    let redrawsPerSecond: Int
    let heavy: Bool
    let reasons: [String]
    /// Measured in the editor with embeds running, not off screen.
    let measuredLive: Bool

    init(slide: Int, load: SlideLoad, measuredLive: Bool) {
        self.slide = slide
        blurs = load.blurs
        loopingAnimations = load.loopingAnimations
        embeds = load.embeds
        redrawsPerSecond = load.redrawsPerSecond
        heavy = load.isHeavy
        reasons = load.reasons
        self.measuredLive = measuredLive
    }

    enum CodingKeys: String, CodingKey {
        case slide, blurs, embeds, heavy, reasons
        case loopingAnimations = "looping_animations"
        case redrawsPerSecond = "redraws_per_second"
        case measuredLive = "measured_live"
    }
}
