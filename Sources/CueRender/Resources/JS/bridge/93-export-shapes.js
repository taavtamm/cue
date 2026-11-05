// Export: the slide's boxes as editable shapes.
//
// An element whose own box paints something PowerPoint can draw — a fill
// (solid or linear gradient), a border, rounded corners, a shadow — becomes
// a shape, in paint order with the text and pictures. A full-slide flat fill
// becomes the slide's background. What can't be expressed (radial or conic
// gradients, url() backgrounds, filters, clip-paths, masks, SVG, canvas,
// embeds, pseudo-element boxes) stays in the flattened picture and is counted.

cue.exportShapes = (() => {
  const SHAPE = 'data-cue-export-shape';

  function alpha(colour) {
    const m = colour.match(/rgba?\(([^)]+)\)/);
    if (!m) return 0;
    const parts = m[1].split(/[\s,/]+/).filter(Boolean).map(Number);
    return parts.length >= 4 ? parts[3] : 1;
  }

  function opacityOf(el, canvas) {
    let value = 1;
    for (let node = el; node && node !== canvas.parentElement; node = node.parentElement) {
      value *= Number(getComputedStyle(node).opacity);
    }
    return value;
  }

  /** `linear-gradient(...)` as an angle and stops, or null. One layer only. */
  function linearGradient(image) {
    if (!image.startsWith('linear-gradient(') || /\)\s*,\s*\w+-gradient\(|url\(/.test(image)) return null;
    const body = image.slice('linear-gradient('.length, -1);
    const parts = body.split(/,(?![^(]*\))/).map((s) => s.trim());
    let angle = 180;
    const sides = { 'to top': 0, 'to right': 90, 'to bottom': 180, 'to left': 270,
                    'to top right': 45, 'to bottom right': 135, 'to bottom left': 225, 'to top left': 315 };
    if (/deg$/.test(parts[0])) angle = parseFloat(parts.shift());
    else if (parts[0] in sides) angle = sides[parts.shift()];
    else if (/turn$/.test(parts[0])) angle = parseFloat(parts.shift()) * 360;
    const stops = parts.map((part) => {
      const colour = (part.match(/rgba?\([^)]*\)/) || [null])[0];
      const position = part.match(/(-?[\d.]+)%\s*$/);
      return colour ? { color: colour, position: position ? Number(position[1]) / 100 : null } : null;
    });
    if (stops.length < 2 || stops.includes(null)) return null;
    stops.forEach((stop, i) => { if (stop.position === null) stop.position = i / (stops.length - 1); });
    return { type: 'linear', angle, stops };
  }

  function fillOf(style) {
    const image = style.backgroundImage;
    if (image && image !== 'none') return linearGradient(image) || 'unsupported';
    return alpha(style.backgroundColor) > 0 ? { type: 'solid', color: style.backgroundColor } : null;
  }

  function side(style, name) {
    const width = parseFloat(style[`border${name}Width`]) || 0;
    const kind = style[`border${name}Style`];
    const colour = style[`border${name}Color`];
    if (width <= 0 || kind === 'none' || kind === 'hidden' || alpha(colour) === 0) return null;
    return { width, color: colour, dash: kind === 'dashed' ? 'dash' : kind === 'dotted' ? 'dot' : 'solid' };
  }

  function shadowOf(style) {
    if (!style.boxShadow || style.boxShadow === 'none' || style.boxShadow.includes('inset')) return null;
    const first = style.boxShadow.split(/,(?![^(]*\))/)[0];
    const colour = (first.match(/rgba?\([^)]*\)/) || [null])[0];
    const numbers = first.replace(/rgba?\([^)]*\)/, '').trim().split(/\s+/).map(parseFloat);
    if (!colour || alpha(colour) === 0) return null;
    return { color: colour, x: numbers[0] || 0, y: numbers[1] || 0, blur: numbers[2] || 0 };
  }

  /** The element's rotation in degrees, null when it's a skew or 3-D transform. */
  function rotationOf(style) {
    if (!style.transform || style.transform === 'none') return 0;
    const m = style.transform.match(/^matrix\(([^)]+)\)$/);
    if (!m) return null;
    const [a, b, c, d] = m[1].split(',').map(Number);
    const sx = Math.hypot(a, b), sy = Math.hypot(c, d);
    if (Math.abs(a * c + b * d) > 0.001 * sx * sy) return null; // Skewed.
    return Math.atan2(b, a) * 180 / Math.PI;
  }

  const OPAQUE_CONTENT = 'svg, canvas, iframe, video, object, embed';

  /** Paints itself and everything inside in ways only a picture can show. */
  function holdsSubtree(el, style) {
    return el.matches(OPAQUE_CONTENT) || style.filter !== 'none' || style.clipPath !== 'none'
      || (style.maskImage && style.maskImage !== 'none') || (style.backdropFilter && style.backdropFilter !== 'none')
      || style.mixBlendMode !== 'normal';
  }

  /** Paints something extra above its box that only a picture can show. */
  function paintsExtra(el, style) {
    if (style.outlineStyle !== 'none' && parseFloat(style.outlineWidth) > 0) return true;
    if (style.display === 'list-item' && style.listStyleType !== 'none') return true;
    for (const pseudo of ['::before', '::after']) {
      const p = getComputedStyle(el, pseudo);
      if (p.content !== 'none' && p.content !== 'normal'
          && (alpha(p.backgroundColor) > 0 || p.backgroundImage !== 'none' || parseFloat(p.borderTopWidth) > 0
              || p.content.replace(/["']/g, '').trim() !== '')) return true;
    }
    return false;
  }

  /** Equal corner radii in px, or null when the corners differ. */
  function radiusOf(style, box) {
    const corners = ['TopLeft', 'TopRight', 'BottomRight', 'BottomLeft'].map((c) => style[`border${c}Radius`]);
    if (corners.some((c) => c !== corners[0])) return null;
    const value = corners[0].split(' ')[0];
    if (value.endsWith('%')) return { px: parseFloat(value) / 100 * Math.min(box.width, box.height), ellipse: parseFloat(value) >= 50 };
    const px = parseFloat(value) || 0;
    const square = Math.abs(box.width - box.height) < 1;
    return { px, ellipse: square && px >= box.width / 2 - 0.5 };
  }

  /** The shape for one element, 'kept' when only the picture can show it, or null. */
  function shapeOf(el, style, box, opacity) {
    const fill = fillOf(style);
    const sides = ['Top', 'Right', 'Bottom', 'Left'].map((name) => side(style, name));
    const shadow = shadowOf(style);
    if (fill === 'unsupported') return 'kept';
    if (!fill && !sides.some(Boolean) && !shadow) return null;
    const rotation = rotationOf(style);
    const radius = radiusOf(style, box);
    if (rotation === null || radius === null) return 'kept';
    const minSide = Math.min(box.width, box.height);
    const uniform = sides.every((s) => s && s.width === sides[0].width && s.color === sides[0].color && s.dash === sides[0].dash);
    // Per-side borders become straight lines: not on a rounded or turned box.
    if (!uniform && sides.some(Boolean) && (radius.px > 0 || rotation !== 0)) return 'kept';
    const thin = minSide <= 4 && fill && fill.type === 'solid' && !sides.some(Boolean) && !shadow;
    const geometry = thin ? 'line' : radius.ellipse ? 'ellipse' : radius.px > 0 ? 'roundRect' : 'rect';
    return {
      box, rotation, geometry, radius: Math.min(radius.px, minSide / 2), opacity,
      fill: thin ? null : fill,
      line: thin ? { width: minSide, color: fill.color, dash: 'solid' } : uniform ? sides[0] : null,
      sides: thin || uniform || !sides.some(Boolean) ? null : sides,
      shadow,
    };
  }

  /** The layer an element paints as within its parent's, or null when it paints in flow. */
  function layerOf(node) {
    const style = getComputedStyle(node);
    const item = node.parentElement && /flex|grid/.test(getComputedStyle(node.parentElement).display);
    const z = parseInt(style.zIndex, 10);
    if (style.position !== 'static' || (item && Number.isFinite(z))) return Number.isFinite(z) ? (z < 0 ? z - 1000 : z) : 0;
    if (Number(style.opacity) < 1 || style.transform !== 'none' || style.filter !== 'none') return 0;
    if (item || /^inline-/.test(style.display)) return -0.25; // Painted whole, like an inline block.
    return null;
  }

  /**
   * Where something paints, as a key that sorts in paint order: for each
   * layered ancestor its layer and tree index, then the element's own phase
   * (its box before its content, as CSS paints backgrounds before text).
   */
  function paintKey(el, own, canvas, indexOf) {
    const key = [];
    const chain = [];
    for (let node = el.parentElement; node && node !== canvas; node = node.parentElement) chain.unshift(node);
    for (const node of chain) {
      const layer = layerOf(node);
      if (layer !== null) key.push(layer, indexOf.get(node));
    }
    if (el === canvas) return [-1e9];
    const index = indexOf.get(el);
    const layer = layerOf(el);
    if (layer !== null) key.push(layer, index, own ? -1e6 : -0.25, index);
    else key.push(own ? -0.75 : -0.25, index);
    return key;
  }

  function compareKeys(a, b) {
    for (let i = 0; i < Math.min(a.length, b.length); i++) if (a[i] !== b[i]) return a[i] - b[i];
    return a.length - b.length;
  }

  /** The box the element has before its own rotation, in canvas pixels. */
  function unrotatedBox(el, style, box) {
    if (style.transform === 'none' || !el.offsetWidth) return box;
    const m = new DOMMatrixReadOnly(style.transform);
    const width = el.offsetWidth * Math.hypot(m.a, m.b), height = el.offsetHeight * Math.hypot(m.c, m.d);
    return { x: box.x + (box.width - width) / 2, y: box.y + (box.height - height) / 2, width, height };
  }

  /** A full-slide fill PowerPoint can use as the slide's background. */
  function backgroundFill(shape) {
    if (!shape || shape.line || shape.sides || shape.shadow || shape.rotation || shape.radius > 0 || shape.opacity < 1) return null;
    const colours = shape.fill.type === 'solid' ? [shape.fill.color] : shape.fill.stops.map((stop) => stop.color);
    return colours.every((colour) => alpha(colour) >= 0.99) ? shape.fill : null;
  }

  /**
   * Shapes and the slide background, in paint order with `parts` (the text
   * blocks and pictures, `{ el, box, held }`). Returns their orders too.
   * ctx: { toBox(rect), bounds, shows(el), overlaps(a, b) }.
   */
  function collect(canvas, parts, ctx) {
    const all = [canvas, ...canvas.querySelectorAll('*')];
    const indexOf = new Map(all.map((el, i) => [el, i]));
    const shapes = [];
    const held = parts.filter((part) => part.held).map((part) => ({ box: part.box, key: paintKey(part.el, false, canvas, indexOf) }));
    const heldRoots = [];
    let unsupported = 0;
    for (const el of all.slice(1)) {
      const embed = el.matches('iframe[data-cue-owned]'); // A live embed Cue runs: only the picture shows it.
      if ((!embed && el.closest('[data-cue-owned], script, style')) || heldRoots.some((root) => root.contains(el))) continue;
      if (!ctx.shows(el)) continue;
      const style = getComputedStyle(el);
      const box = unrotatedBox(el, style, ctx.toBox(el.getBoundingClientRect()));
      if (box.width <= 0 || box.height <= 0 || !ctx.overlaps(ctx.toBox(el.getBoundingClientRect()), ctx.bounds)) continue;
      if (embed || holdsSubtree(el, style)) {
        heldRoots.push(el);
        held.push({ box: ctx.toBox(el.getBoundingClientRect()), key: paintKey(el, true, canvas, indexOf) });
        unsupported++;
        continue;
      }
      if (paintsExtra(el, style)) {
        held.push({ box: ctx.toBox(el.getBoundingClientRect()), key: paintKey(el, false, canvas, indexOf) });
        unsupported++;
      }
      const shape = shapeOf(el, style, box, opacityOf(el, canvas));
      if (shape === 'kept') {
        held.push({ box, key: paintKey(el, true, canvas, indexOf) });
        unsupported++;
      } else if (shape) {
        shapes.push({ ...shape, el, key: paintKey(el, true, canvas, indexOf) });
      }
    }
    // A shape under something only the picture shows stays in the picture too,
    // since the picture lies beneath every shape.
    let kept = 0;
    for (let changed = true; changed;) {
      changed = false;
      for (const shape of shapes) {
        if (shape.held || !held.some((h) => compareKeys(h.key, shape.key) > 0 && ctx.overlaps(h.box, shape.box))) continue;
        shape.held = true;
        held.push(shape);
        kept++;
        changed = true;
      }
    }
    const items = shapes.filter((shape) => !shape.held).map((shape) => ({ kind: 'shape', key: shape.key, shape }))
      .concat(parts.map((part, i) => ({ kind: 'part', key: paintKey(part.el, false, canvas, indexOf), index: i, part })));
    items.sort((a, b) => compareKeys(a.key, b.key));
    // Full-slide fills at the very bottom become the slide's background.
    let background = canvasBackground(canvas);
    while (items.length && items[0].kind === 'shape' && !held.some((h) => compareKeys(h.key, items[0].key) < 0)) {
      const shape = items[0].shape;
      const covers = shape.box.x <= 0.5 && shape.box.y <= 0.5 && shape.box.width >= ctx.bounds.width - 1 && shape.box.height >= ctx.bounds.height - 1;
      const fill = covers && backgroundFill(shape);
      if (!fill) break;
      background = fill;
      shape.el.setAttribute(SHAPE, 'background');
      items.shift();
    }
    const orders = new Array(parts.length);
    const out = [];
    items.forEach((item, order) => {
      if (item.kind === 'part') { orders[item.index] = order; return; }
      const { el, key, held: _, ...shape } = item.shape;
      el.setAttribute(SHAPE, 'shape');
      out.push({ ...shape, order });
    });
    return { shapes: out, background, orders, unsupported, kept, picture: held.length > 0 || background === null };
  }

  /** The canvas's own fill, or the first solid colour behind it, as the slide background. */
  function canvasBackground(canvas) {
    const own = getComputedStyle(canvas);
    const fill = fillOf(own);
    if (fill === 'unsupported') return null;
    // What's behind the slide's background (the player's letterbox) goes too,
    // so the picture is see-through wherever the page paints nothing else.
    const clearBehind = () => { for (let n = canvas; n; n = n.parentElement) n.setAttribute(SHAPE, 'background'); };
    if (fill && backgroundFill({ fill, radius: 0, opacity: 1 })) { clearBehind(); return fill; }
    if (fill) return null; // See-through: the picture keeps it.
    for (let node = canvas.parentElement; node; node = node.parentElement) {
      const style = getComputedStyle(node);
      if (style.backgroundImage !== 'none') return null;
      if (alpha(style.backgroundColor) === 0) continue;
      if (alpha(style.backgroundColor) < 0.99) return null;
      clearBehind();
      return { type: 'solid', color: style.backgroundColor };
    }
    clearBehind();
    return { type: 'solid', color: 'rgb(255, 255, 255)' };
  }

  return { SHAPE, collect };
})();
