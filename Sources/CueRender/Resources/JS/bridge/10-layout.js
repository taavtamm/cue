// Fitting a slide's design canvas into the window: scale to fit, centre,
// letterbox in black. Used by the generic player.

cue.layout = {
  /** Scale that fits `canvas` inside the viewport without cropping. */
  scaleFor(canvas) {
    const root = document.documentElement;
    const scale = Math.min(root.clientWidth / canvas.width, root.clientHeight / canvas.height);
    return scale > 0 && Number.isFinite(scale) ? scale : 1;
  },

  /** Keeps `apply(scale)` in step with the window size. */
  track(canvas, apply) {
    const update = () => apply(cue.layout.scaleFor(canvas));
    window.addEventListener('resize', update);
    update();
    return update;
  },
};
