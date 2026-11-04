// Time anchor: keeps mirrored screens on the same animation frame.
//
// Each screen runs its own WKWebView, so a CSS animation starts whenever
// that page happened to load or show the slide. After a slide change Swift
// reads the stage's clock (wall time + each animation's currentTime) and
// sends it to the other screens, which set the same times, advanced by the
// time the message took. All surfaces share one Mac clock, so this lines
// them up to within a frame. Animations inside cross-origin embeds can't be
// reached and keep their own timing (docs/limits.md).

cue.timeAnchor = (() => {
  /** Running Web Animations whose target is inside the shown slide, in document order. */
  function slideAnimations() {
    if (!player || !player.slides) return [];
    const state = player.debug ? player.debug() : null;
    const index = state && state.current ? state.current.slide : 0;
    const slide = player.slides[index];
    if (!slide) return [];
    return document.getAnimations().filter((animation) => {
      const target = animation.effect && animation.effect.target;
      return target && slide.contains(target) && animation.playState !== 'finished';
    });
  }

  return {
    read() {
      return { wall: Date.now(), times: slideAnimations().map((a) => a.currentTime) };
    },
    apply(clock) {
      const animations = slideAnimations();
      if (animations.length !== clock.times.length) return false; // Different state; don't guess.
      const lag = Math.max(0, Date.now() - clock.wall);
      animations.forEach((animation, i) => {
        const time = clock.times[i];
        if (typeof time === 'number') animation.currentTime = time + (animation.playState === 'paused' ? 0 : lag);
      });
      return true;
    },
  };
})();

cue.handlers.alignAnimations = ({ clock }) => cue.timeAnchor.apply(clock);
