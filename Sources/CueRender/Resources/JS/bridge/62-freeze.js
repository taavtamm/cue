// Freezing live embeds when the editor pauses.
//
// Embeds run in sandboxed frames Cue can't pause, and the embed protocol has
// no "stop". So on pause Swift takes a picture of the page (which includes
// the embeds' pixels), and each running embed is swapped for a still of what
// it showed at that instant: "Paused · frozen frame". Resuming removes the
// stills and the player starts the slide's embeds again.

cue.freeze = (() => {
  const running = () => Array.from(document.querySelectorAll('iframe[srcdoc]'));

  function clear() {
    for (const still of document.querySelectorAll('img[data-cue-frozen]')) still.remove();
  }

  return {
    /** Boxes of the embeds on screen now, in page coordinates. */
    frames() {
      return running()
        .map((frame, index) => ({ index, rect: frame.getBoundingClientRect() }))
        .filter(({ rect }) => rect.width > 0 && rect.height > 0)
        .map(({ index, rect }) => ({ index, rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height } }));
    },

    /** Replaces each listed embed with its still, and stops the embeds.
     *  The player stops them (so their unload isn't mistaken for the embed
     *  navigating away, which would mark it dead); then the stills go in. */
    apply(stills) {
      clear();
      const frames = running();
      const placed = stills
        .map(({ index, src }) => ({ frame: frames[index], src }))
        .filter(({ frame }) => frame)
        .map(({ frame, src }) => ({ host: frame.parentElement, style: frame.getAttribute('style') || '', src }));
      if (cue.onFreeze) cue.onFreeze();
      for (const { host, style, src } of placed) {
        const still = document.createElement('img');
        still.setAttribute('data-cue-owned', '');
        still.setAttribute('data-cue-frozen', '');
        still.setAttribute('alt', '');
        still.setAttribute('style', style);
        still.src = src;
        host.appendChild(still);
      }
    },

    /** Removes the stills; the player restarts the current slide's embeds. */
    thaw() {
      clear();
      if (cue.onThaw) cue.onThaw();
    },
  };
})();
