// Editor queries: how an element looks and where it sits on the slide's
// canvas, the slide's animations for the timeline, and letting live web
// embeds take clicks while the user tries them out.

cue.inspect = (() => {
  const STYLE_PROPERTIES = [
    'font-family', 'font-weight', 'font-size', 'line-height', 'letter-spacing', 'color', 'text-align',
  ];

  const plainRect = (r) => ({ x: r.x, y: r.y, width: r.width, height: r.height });

  /** The slide an element is on, and the box of its design canvas. */
  function canvasBox(element, slideSelector) {
    const slide = element.closest(slideSelector);
    const canvas = (slide && slide.querySelector('.deck-scaler')) || slide || document.documentElement;
    return { slide, rect: canvas.getBoundingClientRect() };
  }

  /** Index of the first build step whose targets contain the element, or null. */
  function buildStepOf(element, slide, steps) {
    if (!slide) return null;
    for (let index = 0; index < steps.length; index += 1) {
      for (const selector of steps[index]) {
        let targets = [];
        try { targets = Array.from(slide.querySelectorAll(selector)); } catch (error) { continue; }
        if (targets.some((target) => target === element || target.contains(element))) return index;
      }
    }
    return null;
  }

  function element(id, slideSelector, canvasWidth, buildSteps) {
    const el = cue.sourceMap.element(id);
    if (!el) return null;
    const { slide, rect: canvas } = canvasBox(el, slideSelector);
    const scale = canvas.width > 0 && canvasWidth > 0 ? canvas.width / canvasWidth : 1;
    const r = el.getBoundingClientRect();
    const computed = getComputedStyle(el);
    const style = {};
    for (const property of STYLE_PROPERTIES) style[property] = computed.getPropertyValue(property);
    return {
      rect: plainRect(r),
      canvas: { x: (r.x - canvas.x) / scale, y: (r.y - canvas.y) / scale, width: r.width / scale, height: r.height / scale },
      style,
      build: buildStepOf(el, slide, buildSteps || []),
      isLeaf: el.children.length === 0,
      hostsEmbed: !!el.querySelector('iframe[srcdoc]'),
    };
  }

  /** A short name for an animation's target, for the timeline. */
  function describe(target) {
    const label = target.getAttribute('data-label') || target.getAttribute('aria-label');
    if (label) return label;
    const text = (target.textContent || '').trim().replace(/\s+/g, ' ');
    if (text) return text.length > 28 ? text.slice(0, 27) + '…' : text;
    const className = typeof target.className === 'string' ? target.className.split(/\s+/)[0] : '';
    return target.localName + (className ? '.' + className : '');
  }

  function slideAt(slideSelector, index) {
    return document.querySelectorAll(slideSelector)[index] || null;
  }

  function animationsOn(slide) {
    return document.getAnimations().filter((a) => {
      const target = a.effect && a.effect.target;
      return target && slide && slide.contains(target) && !target.closest('[data-cue-owned]');
    });
  }

  function animations(slideSelector, index) {
    const slide = slideAt(slideSelector, index);
    const tracks = animationsOn(slide).map((a) => {
      const timing = a.effect.getTiming();
      const computed = a.effect.getComputedTiming();
      return {
        name: a.animationName || a.transitionProperty || a.id || 'animation',
        target: describe(a.effect.target),
        delay: Number(timing.delay) || 0,
        duration: typeof computed.duration === 'number' ? computed.duration : 0,
        iterations: computed.iterations === Infinity ? -1 : Number(computed.iterations) || 1,
        easing: String(timing.easing || 'linear'),
      };
    });
    const embeds = slide ? slide.querySelectorAll('iframe[srcdoc]').length : 0;
    return { tracks, embeds };
  }

  /** Plays the slide's animations again from their start. */
  function replay(slideSelector, index) {
    for (const animation of animationsOn(slideAt(slideSelector, index))) {
      animation.currentTime = 0;
      animation.play();
    }
  }

  /** True when an element paints something of its own at a point: text,
   *  media, or a background. Empty layout boxes let what's below show. */
  function paintsOwnContent(el) {
    if (el.matches('img, svg, video, canvas, picture, input, textarea, button')) return true;
    for (const node of el.childNodes) {
      if (node.nodeType === Node.TEXT_NODE && node.textContent.trim() !== '') return true;
    }
    const style = getComputedStyle(el);
    const fill = style.backgroundColor;
    return style.backgroundImage !== 'none' || (fill !== 'transparent' && !/rgba\(.*,\s*0\)$/.test(fill));
  }

  /** The box of the live embed under a point, if it is what the user sees
   *  there. Some decks run an embed as a full-slide background with text on
   *  top: a double-click on that text must edit the text, not the embed.
   *  So walk the stack top-down and stop at the first thing that paints. */
  function embedAt(x, y) {
    const frames = Array.from(document.querySelectorAll('iframe[srcdoc]'));
    if (frames.length === 0) return null;
    // Embeds are inert and ignore pointer events, which also hides them from
    // hit testing. Lift both for this one synchronous query (nothing paints).
    const saved = frames.map((frame) => ({ pointer: frame.style.pointerEvents, inert: frame.hasAttribute('inert') }));
    frames.forEach((frame) => { frame.style.pointerEvents = 'auto'; frame.removeAttribute('inert'); });
    try {
      for (const el of document.elementsFromPoint(x, y)) {
        if (el.matches('iframe[srcdoc]')) return plainRect(el.getBoundingClientRect());
        if (paintsOwnContent(el)) return null;
      }
      return null;
    } finally {
      frames.forEach((frame, i) => {
        frame.style.pointerEvents = saved[i].pointer;
        frame.toggleAttribute('inert', saved[i].inert);
      });
    }
  }

  /** Lets embeds take clicks (the user double-clicked one to try it) or makes them inert again. */
  function setEmbedsInteractive(on) {
    for (const frame of document.querySelectorAll('iframe[srcdoc]')) {
      frame.toggleAttribute('inert', !on);
      frame.style.pointerEvents = on ? 'auto' : 'none';
    }
  }

  return { element, animations, replay, embedAt, setEmbedsInteractive };
})();
