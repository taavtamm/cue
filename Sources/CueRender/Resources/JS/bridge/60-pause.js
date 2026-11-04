// Pausing live content in the editor.
//
// Pauses Web Animations (CSS animations and transitions included) and
// media in the page, and keeps catching ones that start while paused.
// Cross-origin embeds and scripts that run their own requestAnimationFrame
// loops can't be paused from here; the editor tells the user so.

cue.pause = (() => {
  let paused = false;
  let catchTimer = 0;
  const held = new Set();

  function holdEverything() {
    for (const animation of document.getAnimations()) {
      if (animation.playState === 'running') {
        animation.pause();
        held.add(animation);
      }
    }
    for (const media of document.querySelectorAll('video, audio')) {
      if (!media.paused) {
        media.pause();
        held.add(media);
      }
    }
  }

  function releaseEverything() {
    for (const item of held) {
      const result = item.play();
      if (result && result.catch) result.catch(() => {});
    }
    held.clear();
  }

  return {
    set(on) {
      if (on === paused) return;
      paused = on;
      clearInterval(catchTimer);
      if (on) {
        holdEverything();
        catchTimer = setInterval(holdEverything, 250);
      } else {
        releaseEverything();
      }
    },
    get isPaused() {
      return paused;
    },
  };
})();
