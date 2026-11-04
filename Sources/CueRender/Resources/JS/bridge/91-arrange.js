// Moving and resizing on the slide. While the user drags, Swift previews the
// new inline style on the live element (nothing is written yet); on release
// it commits one source edit, whose live update replaces the preview with
// exactly what the file says. Also: the slide's canvas box and the other
// boxes on it, for snapping.

cue.arrange = (() => {
  const previews = new Map(); // id -> original style attribute (or null)

  /** The slide's design canvas: its box in the viewport and its scale. */
  function canvas(slideSelector, index, canvasWidth) {
    const slide = document.querySelectorAll(slideSelector)[index];
    if (!slide) return null;
    const box = slide.querySelector('.deck-scaler') || slide;
    const r = box.getBoundingClientRect();
    const scale = canvasWidth > 0 && r.width > 0 ? r.width / canvasWidth : 1;
    return { rect: { x: r.x, y: r.y, width: r.width, height: r.height }, scale };
  }

  /** Mapped, visible boxes on the slide, in canvas pixels, to snap to. */
  function boxes(slideSelector, index, canvasWidth, excludeID) {
    const info = canvas(slideSelector, index, canvasWidth);
    const slide = document.querySelectorAll(slideSelector)[index];
    if (!info || !slide) return [];
    const { rect: c, scale } = info;
    const result = [];
    for (const element of slide.querySelectorAll('[data-cue-id]')) {
      if (element.getAttribute('data-cue-id') === excludeID || element.closest('[data-cue-id="' + excludeID + '"]')) continue;
      const r = element.getBoundingClientRect();
      if (r.width < 4 || r.height < 4 || (r.width >= c.width * 0.98 && r.height >= c.height * 0.98)) continue;
      result.push({ x: (r.x - c.x) / scale, y: (r.y - c.y) / scale, width: r.width / scale, height: r.height / scale });
      if (result.length >= 300) break;
    }
    return result;
  }

  /** Shows `styles` ({property: value or null}) on the element, live only. */
  function preview(id, styles) {
    const element = cue.sourceMap.element(id);
    if (!element) return false;
    if (!previews.has(id)) previews.set(id, element.getAttribute('style'));
    for (const [property, value] of Object.entries(styles)) {
      if (value === null) element.style.removeProperty(property);
      else element.style.setProperty(property, value);
    }
    return true;
  }

  /** Puts the element's style back as it was before the preview. */
  function cancel(id) {
    const element = cue.sourceMap.element(id);
    if (!previews.has(id)) return;
    const original = previews.get(id);
    previews.delete(id);
    if (!element) return;
    if (original === null) element.removeAttribute('style');
    else element.setAttribute('style', original);
  }

  /** The source edit has landed; its live update set the real style. */
  const forget = (id) => previews.delete(id);

  return { canvas, boxes, preview, cancel, forget };
})();
