// Live source mapping: tags each DOM element with the `data-cue-id` of the
// same element in the deck's source, so a click resolves to a source range.
//
// Swift sends a manifest of [cueID, tag] in source document order. The DOM
// was built by the same HTML parsing rules, so walking it in document order
// lines up one-to-one, unless a deck script added or removed elements. Then
// we resync on the next matching tag and report what couldn't be mapped.
// The ids live in memory only; they are never in the source or on disk.

cue.sourceMap = (() => {
  let byID = new Map();

  /** Elements in document order, including <template> contents, minus Cue's own. */
  function liveElements() {
    const result = [];
    const visit = (element) => {
      if (element.hasAttribute('data-cue-owned')) return;
      result.push(element);
      const children = element.localName === 'template' && element.content ? element.content.children : element.children;
      for (const child of children) visit(child);
    };
    visit(document.documentElement);
    return result;
  }

  const sameTag = (a, b) => a.toLowerCase() === b.toLowerCase();
  const LOOKAHEAD = 64;

  function assign(manifest) {
    for (const element of byID.values()) element.removeAttribute('data-cue-id');
    byID = new Map();
    const live = liveElements();
    let next = 0;
    let unmapped = 0;
    for (const element of live) {
      let match = next;
      const limit = Math.min(manifest.length, next + LOOKAHEAD);
      while (match < limit && !sameTag(manifest[match][1], element.localName)) match += 1;
      if (match >= limit) {
        unmapped += 1; // Made by a deck script: it has no source.
        continue;
      }
      const id = manifest[match][0];
      element.setAttribute('data-cue-id', id);
      byID.set(id, element);
      next = match + 1;
    }
    const exact = unmapped === 0 && byID.size === manifest.length && live.length === manifest.length;
    return { mapped: byID.size, unmapped, missing: manifest.length - byID.size, exact };
  }

  const element = (id) => byID.get(String(id)) || null;

  /** Inline pieces of text (font, span, b, a…) can't be moved or sized on
   *  their own: a click on them means the text box they sit in. */
  const isInline = (el) => {
    const display = getComputedStyle(el).display;
    return display === 'inline' || display === 'contents';
  };

  /** The slide's background: the slide itself, the page around it, or a
   *  box covering (almost) the whole slide. Pictures are never background,
   *  so a full-bleed photo can still be picked. */
  function isBackground(el) {
    if (el.matches('img, video, svg, canvas, picture, iframe')) return false;
    const selector = cue.config && cue.config.slideSelector;
    const slide = selector ? el.closest(selector) : null;
    if (!slide || el === slide) return true;
    const canvas = (slide.querySelector('.deck-scaler > *') || slide).getBoundingClientRect();
    const box = el.getBoundingClientRect();
    return box.width >= canvas.width * 0.95 && box.height >= canvas.height * 0.95;
  }

  /** The mapped element under a point in CSS pixels of the viewport: the
   *  nearest box that isn't inline, so clicking text selects its text box.
   *  Nothing (null) on the slide's background, so a click there deselects. */
  function at(x, y) {
    let target = mappedAncestor(document.elementFromPoint(x, y));
    while (target && isInline(target)) {
      const box = mappedAncestor(target.parentElement);
      if (!box || box === document.body || box === document.documentElement) break;
      target = box;
    }
    if (!target || isBackground(target)) return null;
    const rect = target.getBoundingClientRect();
    return { cueID: target.getAttribute('data-cue-id'), tag: target.localName,
      rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height } };
  }

  /** The nearest element (itself included) that maps to the source. */
  function mappedAncestor(node) {
    let target = node;
    while (target && !(target.hasAttribute && target.hasAttribute('data-cue-id'))) target = target.parentElement;
    return target || null;
  }

  /** The id of an element Cue already holds (e.g. from a selection). */
  const idOf = (node) => {
    const target = mappedAncestor(node);
    return target ? target.getAttribute('data-cue-id') : null;
  };

  return { assign, element, at, idOf };
})();
