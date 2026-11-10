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

    /// Measures the shown slide's GPU load once it has settled (2 s), unless
    /// the user has moved on by then.
    func measureLoadSoon() {
        let index = slide
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.slide == index else { return }
            guard let load = try? await self.canvas.load(onSlide: index, slideSelector: self.structure.slideSelector),
                  self.slide == index else { return }
            self.loads[index] = load
        }
    }
}
