// Export: what a slide shows, as editable parts.
//
// `collect` walks the slide's design canvas and returns every visible text
// block (its box, alignment, line height and styled runs), every plain
// picture and (from `93-export-shapes.js`) every box PowerPoint can draw as
// a shape, in canvas pixels and paint order, and marks them. `hideMarked(true)`
// then hides exactly those, keeping layout, so a picture of the slide without
// them carries only what PowerPoint can't draw (radial gradients, SVG,
// canvas, live embeds…).

cue.exporter = (() => {
  const HIDE_ID = 'cue-export-hide';
  const MARK = 'data-cue-export';
  const INLINE = new Set(['inline', 'contents']);

  function canvasOf(slideSelector, index) {
    const slide = document.querySelectorAll(slideSelector)[index];
    if (!slide) return null;
    return slide.querySelector('.deck-scaler > *') || slide;
  }

  /** Visible, rendered and not under something hidden. */
  function shows(el, canvas) {
    for (let node = el; node && node !== canvas.parentElement; node = node.parentElement) {
      const style = getComputedStyle(node);
      if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) return false;
    }
    return true;
  }

  /** The nearest ancestor that lays out as a box (not inline). */
  function blockOf(node, canvas) {
    let el = node.nodeType === Node.ELEMENT_NODE ? node : node.parentElement;
    while (el && el !== canvas && INLINE.has(getComputedStyle(el).display)) el = el.parentElement;
    return el || canvas;
  }

  function transformText(text, style) {
    switch (style.textTransform) {
      case 'uppercase': return text.toUpperCase();
      case 'lowercase': return text.toLowerCase();
      case 'capitalize': return text.replace(/\b\p{L}/gu, (c) => c.toUpperCase());
      default: return text;
    }
  }

  function px(value, fallback) {
    const number = parseFloat(value);
    return Number.isFinite(number) ? number : fallback;
  }

  /** What kind of font the stack asks for, so apps without it can substitute well. */
  function genericOf(stack) {
    const names = stack.toLowerCase();
    if (/monospace|mono\b|courier|consolas|menlo/.test(names)) return 'monospace';
    if (/(^|,)\s*serif|georgia|times|garamond|baskerville/.test(names) && !/sans-serif/.test(names)) return 'serif';
    return 'sans-serif';
  }

  function run(text, style) {
    const size = px(style.fontSize, 16);
    return {
      text: transformText(text, style),
      family: style.fontFamily.split(',')[0].trim().replace(/^["']|["']$/g, ''),
      generic: genericOf(style.fontFamily),
      weight: Number(style.fontWeight) || 400,
      italic: style.fontStyle === 'italic' || style.fontStyle.startsWith('oblique'),
      underline: style.textDecorationLine.includes('underline'),
      size,
      color: style.webkitTextFillColor && style.webkitTextFillColor !== style.color && !/currentcolor/i.test(style.webkitTextFillColor)
        ? style.webkitTextFillColor : style.color,
      letterSpacing: style.letterSpacing === 'normal' ? 0 : px(style.letterSpacing, 0),
    };
  }

  /** Paragraphs of runs for one block: its own text, split at <br>. */
  function paragraphsOf(block, canvas) {
    const paragraphs = [[]];
    const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (node.nodeType === Node.ELEMENT_NODE) {
        if (node.localName === 'br' && blockOf(node.parentElement, canvas) === block) paragraphs.push([]);
        continue;
      }
      if (blockOf(node, canvas) !== block || !node.textContent.trim()) continue;
      if (!shows(node.parentElement, canvas)) continue;
      const text = node.textContent.replace(/\s+/g, ' ');
      paragraphs[paragraphs.length - 1].push(run(text, getComputedStyle(node.parentElement)));
    }
    return paragraphs.filter((runs) => runs.length > 0).map((runs, i, all) => {
      if (i === 0) runs[0].text = runs[0].text.replace(/^\s+/, '');
      const last = runs[runs.length - 1];
      last.text = last.text.replace(/\s+$/, '');
      return runs;
    });
  }

  function lineCount(block) {
    const range = document.createRange();
    range.selectNodeContents(block);
    const tops = new Set(Array.from(range.getClientRects()).filter((r) => r.width > 0).map((r) => Math.round(r.top)));
    return tops.size;
  }

  function align(style) {
    switch (style.textAlign) {
      case 'center': return 'center';
      case 'right': case 'end': return 'right';
      case 'justify': return 'justify';
      default: return 'left';
    }
  }

  function box(rect, origin, scale) {
    return { x: (rect.x - origin.x) / scale, y: (rect.y - origin.y) / scale,
             width: rect.width / scale, height: rect.height / scale };
  }

  function overlaps(a, b) {
    return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
  }

  function isRotated(el) {
    const matrix = getComputedStyle(el).transform;
    if (!matrix || matrix === 'none') return false;
    const values = matrix.match(/matrix\(([^)]+)\)/);
    if (!values) return true; // 3-D: keep it in the picture.
    const [, b, c] = values[1].split(',').map(Number);
    return Math.abs(b) > 0.001 || Math.abs(c) > 0.001;
  }

  function collect(slideSelector, index, canvasWidth) {
    clear();
    const canvas = canvasOf(slideSelector, index);
    if (!canvas) return null;
    const origin = canvas.getBoundingClientRect();
    const scale = origin.width / canvasWidth || 1;
    const bounds = { x: 0, y: 0, width: canvasWidth, height: origin.height / scale };

    const blocks = new Set();
    const walker = document.createTreeWalker(canvas, NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (!node.textContent.trim() || node.parentElement.closest('svg, iframe, canvas, script, style, [data-cue-owned]')) continue;
      if (!shows(node.parentElement, canvas)) continue;
      blocks.add(blockOf(node, canvas));
    }
    const texts = [];
    const parts = [];
    for (const block of blocks) {
      const frame = box(block.getBoundingClientRect(), origin, scale);
      if (frame.width < 1 || frame.height < 1 || !overlaps(frame, bounds)) continue;
      if (isRotated(block)) { parts.push({ el: block, box: frame, held: true }); continue; }
      const paragraphs = paragraphsOf(block, canvas);
      if (paragraphs.length === 0) continue;
      const style = getComputedStyle(block);
      const size = px(style.fontSize, 16);
      texts.push({ box: frame, paragraphs, align: align(style),
                   lineHeight: style.lineHeight === 'normal' ? size * 1.2 : px(style.lineHeight, size * 1.2),
                   wraps: lineCount(block) > 1 || paragraphs.length > 1 });
      parts.push({ el: block, box: frame, item: texts[texts.length - 1] });
      block.setAttribute(MARK, 'text');
    }

    const images = [];
    for (const img of canvas.querySelectorAll('img')) {
      if (!img.complete || img.naturalWidth === 0 || !shows(img, canvas) || isRotated(img)) continue;
      if (img.closest('[data-cue-owned]')) continue;
      const frame = box(img.getBoundingClientRect(), origin, scale);
      if (frame.width < 2 || frame.height < 2 || !overlaps(frame, bounds)) continue;
      const style = getComputedStyle(img);
      images.push({ box: frame, source: img.currentSrc || img.src, naturalWidth: img.naturalWidth,
                    naturalHeight: img.naturalHeight, fit: style.objectFit || 'fill',
                    opacity: Number(style.opacity) });
      parts.push({ el: img, box: frame, item: images[images.length - 1] });
      img.setAttribute(MARK, 'image');
    }
    const drawn = cue.exportShapes.collect(canvas, parts, {
      toBox: (rect) => box(rect, origin, scale), bounds, overlaps, shows: (el) => shows(el, canvas),
    });
    parts.forEach((part, i) => { if (part.item) part.item.order = drawn.orders[i]; });
    return { canvas: { x: origin.x, y: origin.y, width: origin.width, height: origin.height },
             width: canvasWidth, height: bounds.height, texts, images, shapes: drawn.shapes,
             background: drawn.background, unsupported: drawn.unsupported, keptShapes: drawn.kept,
             needsPicture: drawn.picture };
  }

  /** Hides what `collect` marked (layout kept) for the background picture. */
  function hideMarked(on) {
    let style = document.getElementById(HIDE_ID);
    if (!on) { if (style) style.remove(); return; }
    if (!style) {
      style = document.createElement('style');
      style.id = HIDE_ID;
      style.setAttribute('data-cue-owned', '');
      document.head.appendChild(style);
    }
    const SHAPE = cue.exportShapes.SHAPE;
    style.textContent = `[${SHAPE}]{background:none!important;border-color:transparent!important;box-shadow:none!important}`
      + `[${MARK}="image"]{visibility:hidden!important}`
      + `[${MARK}="text"],[${MARK}="text"] *{color:transparent!important;-webkit-text-fill-color:transparent!important;`
      + `text-shadow:none!important;text-decoration-color:transparent!important}`;
  }

  function clear() {
    hideMarked(false);
    for (const el of document.querySelectorAll(`[${MARK}]`)) el.removeAttribute(MARK);
    const SHAPE = cue.exportShapes.SHAPE;
    for (const el of document.querySelectorAll(`[${SHAPE}]`)) el.removeAttribute(SHAPE);
  }

  /** An image Swift couldn't read stays in the background picture instead. */
  function keepInBackground(imageIndex) {
    const image = document.querySelectorAll(`[${MARK}="image"]`)[imageIndex];
    if (image) image.setAttribute(MARK, 'kept');
  }

  return { collect, hideMarked, clear, keepInBackground };
})();
