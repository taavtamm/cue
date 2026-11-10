import Foundation

/// What keeps the GPU busy while a slide plays, measured on the live page.
/// Cue can't make a frame cheaper, so a heavy deck gets a warning and a
/// prompt the user can hand to their AI to make the deck lighter.
public struct SlideLoad: Sendable, Equatable, Codable {
    /// Visible elements with a `backdrop-filter`: re-blurred whenever anything behind them moves.
    public var blurs: Int
    /// Animations that never end.
    public var loopingAnimations: Int
    /// Live embeds, video and canvas: they draw on their own.
    public var embeds: Int
    /// The deck's own `requestAnimationFrame` calls per second.
    public var redrawsPerSecond: Int

    public init(blurs: Int, loopingAnimations: Int, embeds: Int, redrawsPerSecond: Int) {
        self.blurs = blurs
        self.loopingAnimations = loopingAnimations
        self.embeds = embeds
        self.redrawsPerSecond = redrawsPerSecond
    }

    /// Something moves on the slide all the time.
    public var keepsMoving: Bool { loopingAnimations > 0 || embeds > 0 || redrawsPerSecond >= Self.everyFrame }

    /// Why this slide is heavy, worded for the user; empty when it isn't.
    public var reasons: [String] {
        var reasons: [String] = []
        if blurs >= Self.blurLimit, keepsMoving { reasons.append(Self.count(blurs, "blur", "over moving content")) }
        if loopingAnimations >= Self.loopLimit {
            reasons.append(Self.count(loopingAnimations, "animation", "that never stop"))
        }
        if embeds >= Self.embedLimit { reasons.append(Self.count(embeds, "embed", "that draw on their own")) }
        if redrawsPerSecond >= Self.everyFrame { reasons.append("scripts redrawing every frame") }
        return reasons
    }

    public var isHeavy: Bool { !reasons.isEmpty }

    /// Thresholds. Blurs only count over moving content: a still blur is
    /// drawn once.
    static let blurLimit = 3
    static let loopLimit = 6
    static let embedLimit = 2
    static let everyFrame = 30

    private static func count(_ n: Int, _ noun: String, _ tail: String) -> String {
        "\(n) \(noun)\(n == 1 ? "" : "s") \(tail)"
    }
}
