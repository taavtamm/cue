import CueCore
import Foundation

/// Sends one show position to every surface: stage and mirrors, the
/// presenter's current slide, and next-slide previews. Displays stay in sync
/// through state, not pixels; after each slide change the mirrors' animation
/// clocks are lined up with the stage's.
@MainActor
public final class ShowBroadcaster {
    public private(set) var renderers: [SlideRenderer] = []
    /// Line mirrored animations up after each slide change.
    public var keepsAnimationsInSync = true
    /// How long after a slide change to read the stage's clock, so the
    /// transition has run and embeds have started.
    public var alignmentDelay: Duration = .milliseconds(450)

    private var stateCounts: [Int]
    private var lastSlide: Int?
    private var alignment: Task<Void, Never>?

    public init(stateCounts: [Int]) {
        self.stateCounts = stateCounts.map { max(1, $0) }
    }

    public func add(_ renderer: SlideRenderer) {
        guard !renderers.contains(where: { $0 === renderer }) else { return }
        renderers.append(renderer)
    }

    public func remove(_ renderer: SlideRenderer) {
        renderers.removeAll { $0 === renderer }
    }

    public func update(stateCounts: [Int]) {
        self.stateCounts = stateCounts.map { max(1, $0) }
    }

    /// The position every surface should show, with blanking for audience screens.
    public func broadcast(_ position: ShowPosition, black: Bool = false, white: Bool = false) {
        for renderer in renderers {
            switch renderer.surface {
            case .stage, .mirror:
                renderer.setCover(black: black, white: white)
                renderer.show(position)
            case .presenterCurrent, .editor:
                renderer.show(position)
            case .nextPreview:
                if let preview = Self.preview(after: position, stateCounts: stateCounts) {
                    renderer.setCover()
                    renderer.show(preview.position, finished: preview.finished)
                } else {
                    renderer.setCover(black: true) // End of show.
                }
            case .thumbnail, .export:
                break
            }
        }
        if position.slide != lastSlide {
            lastSlide = position.slide
            scheduleAlignment()
        }
    }

    /// What the next-slide preview shows: the next build of this slide if it
    /// has one left, else the next slide finished. Nil at the end of the show.
    public static func preview(after position: ShowPosition, stateCounts: [Int])
        -> (position: ShowPosition, finished: Bool)? {
        guard stateCounts.indices.contains(position.slide) else { return nil }
        if position.build + 1 < stateCounts[position.slide] {
            return (ShowPosition(slide: position.slide, build: position.build + 1), false)
        }
        guard position.slide + 1 < stateCounts.count else { return nil }
        return (ShowPosition(slide: position.slide + 1), true)
    }

    /// Reads the stage's animation clock and applies it to the other live surfaces.
    public func alignNow() async {
        guard let stage = renderers.first(where: { $0.surface == .stage && $0.isReady }),
              let clock = await stage.readAnimationClock()
        else { return }
        for renderer in renderers where renderer !== stage {
            if renderer.surface == .mirror || renderer.surface == .presenterCurrent {
                renderer.alignAnimations(to: clock)
            }
        }
    }

    private func scheduleAlignment() {
        alignment?.cancel()
        guard keepsAnimationsInSync else { return }
        let delay = alignmentDelay
        alignment = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.alignNow()
        }
    }
}
