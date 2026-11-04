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

  /** The mapped element under a point in CSS pixels of the viewport. */
  function at(x, y) {
    let target = document.elementFromPoint(x, y);
    while (target && !target.hasAttribute('data-cue-id')) target = target.parentElement;
    if (!target) return null;
    const rect = target.getBoundingClientRect();
    return { cueID: target.getAttribute('data-cue-id'), tag: target.localName,
      rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height } };
  }

  /** The id of an element Cue already holds (e.g. from a selection). */
  const idOf = (node) => {
    let target = node;
    while (target && !(target.hasAttribute && target.hasAttribute('data-cue-id'))) target = target.parentElement;
    return target ? target.getAttribute('data-cue-id') : null;
  };

  return { assign, element, at, idOf };
})();
