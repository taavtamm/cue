import CueRender
import Foundation

/// The timeline under the slide reads the slide's running animations.
extension EditorSession {
    public func refreshAnimations() async {
        let index = slide
        guard let found = try? await canvas.animations(onSlide: index, slideSelector: structure.slideSelector),
              index == slide else { return }
        animations = found
    }

    /// Plays the slide's animations again from the start.
    public func replayAnimations() async {
        try? await canvas.replayAnimations(onSlide: slide, slideSelector: structure.slideSelector)
    }

    public var timeline: TimelineLayout { TimelineLayout(animations) }
}
