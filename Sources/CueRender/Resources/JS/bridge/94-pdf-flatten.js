// PDF export: WebKit writes CSS gradients into a PDF without their
// transparency, so a gradient that fades into a photo comes out solid and
// hides it, and a gradient mask turns its box black.
//
// `find` lists the boxes on a slide that would come out wrong: a see-through
// gradient background, or a gradient mask. For each, Swift calls `isolate`,
// takes a see-through picture of just that box, and `replace` puts the
// picture in as the box's background. A background keeps the box's text and
// borders real; a masked box becomes its picture, contents and all.
// `restore` undoes everything.

cue.pdfFlatten = (() => {
  const MARK = 'data-cue-pdf-flat';
  const SAVED = 'data-cue-pdf-style';
  const ISOLATE_ID = 'cue-pdf-isolate';
  const FLAT_ID = 'cue-pdf-flat';
  let items = [];

  function canvasOf(slideSelector, index) {
    const slide = document.querySelectorAll(slideSelector)[index];
    if (!slide) return null;
    return slide.querySelector('.deck-scaler > *') || slide;
  }

  /** True when a gradient in `image` has a colour stop that isn't opaque. */
  function seeThroughGradient(image) {
    if (!image || !image.includes('gradient(')) return false;
    if (/\btransparent\b/.test(image)) return true;
    for (const match of image.matchAll(/rgba\(([^)]*)\)/g)) {
      const parts = match[1].split(/[\s,/]+/).filter(Boolean);
      if (parts.length >= 4 && Number(parts[3]) < 1) return true;
    }
    return /\/\s*0?\.\d+\s*\)/.test(image); // color(… / 0.5) and friends
  }

  function kindOf(style) {
    const mask = style.maskImage || style.webkitMaskImage || 'none';
    if (mask.includes('gradient(')) return 'whole';
    if (seeThroughGradient(style.backgroundImage)) return 'background';
    return null;
  }

  function shows(el) {
    for (let node = el; node; node = node.parentElement) {
      const style = getComputedStyle(node);
      if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) return false;
    }
    return true;
  }

  function sheet(id) {
    let style = document.getElementById(id);
    if (!style) {
      style = document.createElement('style');
      style.id = id;
      style.setAttribute('data-cue-owned', '');
      document.head.appendChild(style);
    }
    return style;
  }

  /** The boxes to flatten, as rects in web view pixels (clipped to the slide). */
  function find(slideSelector, index) {
    restore();
    const canvas = canvasOf(slideSelector, index);
    if (!canvas) return [];
    const bounds = canvas.getBoundingClientRect();
    const found = [];
    for (const el of [canvas, ...canvas.querySelectorAll('*')]) {
      if (!(el instanceof HTMLElement) || el.closest('[data-cue-owned]')) continue;
      if (found.some((item) => item.kind === 'whole' && item.el.contains(el))) continue;
      const kind = kindOf(getComputedStyle(el));
      if (!kind || !shows(el)) continue;
      const rect = el.getBoundingClientRect();
      // Rotated or skewed boxes: the picture wouldn't line up with the box.
      const scale = el.offsetWidth > 0 ? rect.width / el.offsetWidth : 0;
      if (!(scale > 0) || Math.abs(rect.height - el.offsetHeight * scale) > 1) continue;
      const left = Math.max(rect.left, bounds.left), top = Math.max(rect.top, bounds.top);
      const right = Math.min(rect.right, bounds.right), bottom = Math.min(rect.bottom, bounds.bottom);
      if (right - left < 1 || bottom - top < 1) continue;
      found.push({
        el, kind,
        box: { x: left, y: top, width: right - left, height: bottom - top },
        // Where the picture sits in the box's own (unscaled) pixels.
        place: { x: (left - rect.left) / scale, y: (top - rect.top) / scale,
                 width: (right - left) / scale, height: (bottom - top) / scale },
      });
    }
    items = found;
    items.forEach((item, i) => item.el.setAttribute(MARK, String(i)));
    return items.map((item) => item.box);
  }

  /** Shows only box `i` (only its background, unless its mask is the point). */
  function isolate(i) {
    const item = items[i];
    if (!item) return;
    // `:root:root` outranks the players' own !important rules (the black
    // backdrop, the shown slide's forced visibility).
    const target = `:root:root [${MARK}="${i}"]`;
    const plain = `[${MARK}="${i}"]`;
    let css = `:root:root,:root:root body{background:transparent!important}`
      + `:root:root body::before{visibility:hidden!important;background:transparent!important}`
      + `:root:root,:root:root :not(${plain},${plain} *){visibility:hidden!important}`
      + `${target},:root:root :has(${plain}){opacity:1!important}`
      + `${target}{visibility:visible!important}`;
    if (item.kind === 'background') {
      css += `${target} *,${target}::before,${target}::after{visibility:hidden!important}`
        + `${target}{color:transparent!important;-webkit-text-fill-color:transparent!important;`
        + `text-shadow:none!important;border-color:transparent!important;box-shadow:none!important;outline:none!important}`;
    }
    sheet(ISOLATE_ID).textContent = css;
  }

  /** Box `i` paints `url` (a picture of what `isolate` showed) instead. */
  function replace(i, url) {
    const item = items[i];
    sheet(ISOLATE_ID).textContent = '';
    if (!item) return;
    const el = item.el;
    if (!el.hasAttribute(SAVED)) el.setAttribute(SAVED, el.getAttribute('style') || '');
    const p = item.place;
    el.style.setProperty('background', `url("${url}") ${p.x}px ${p.y}px / ${p.width}px ${p.height}px no-repeat border-box border-box`, 'important');
    if (item.kind === 'whole') {
      el.style.setProperty('mask-image', 'none', 'important');
      el.style.setProperty('-webkit-mask-image', 'none', 'important');
      el.setAttribute(MARK, 'whole');
      const whole = `:root:root [${MARK}="whole"]`;
      sheet(FLAT_ID).textContent = `${whole} *,${whole}::before,${whole}::after{visibility:hidden!important}`
        + `${whole}{color:transparent!important;-webkit-text-fill-color:transparent!important;`
        + `text-shadow:none!important;border-color:transparent!important;box-shadow:none!important;outline:none!important}`;
    }
  }

  function restore() {
    for (const id of [ISOLATE_ID, FLAT_ID]) document.getElementById(id)?.remove();
    for (const el of document.querySelectorAll(`[${SAVED}]`)) {
      const saved = el.getAttribute(SAVED);
      if (saved) el.setAttribute('style', saved); else el.removeAttribute('style');
      el.removeAttribute(SAVED);
    }
    for (const el of document.querySelectorAll(`[${MARK}]`)) el.removeAttribute(MARK);
    items = [];
  }

  return { find, isolate, replace, restore };
})();
