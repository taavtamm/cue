// Player for every other deck Cue understands (Cue's own convention,
// reveal.js markup, role-tagged pages, top-level sections).
//
// It shows one slide element, pinned to the window centre and scaled from
// its design canvas, over a black backdrop. Build steps hide their target
// elements until the step is reached. A slide's `data-cue-transition`
// (fade, push, magic) plays when moving on from it, as in Claude Design decks.

cue.createGenericPlayer = (config) => {
  const slides = Array.from(document.querySelectorAll(config.slideSelector));
  const wholePage = slides.length === 1 && (slides[0] === document.body || slides[0] === document.documentElement);
  const { width, height } = config.canvas;
  let current = null;
  let finishTransition = null;
  const animates = ['stage', 'mirror', 'presenterCurrent', 'editor'].includes(config.surface);

  cue.setStyle('cue-generic-player', `
    html, body { overflow: hidden !important; background: #000 !important; }
    ${wholePage ? '' : `
    body::before { content: ''; position: fixed; inset: 0; background: #000; z-index: 2147482999; }
    [data-cue-off] { display: none !important; }
    [data-cue-ancestor] { transform: none !important; filter: none !important; perspective: none !important;
      contain: none !important; overflow: visible !important; }
    [data-cue-on], [data-cue-leaving] {
      position: fixed !important; left: 50% !important; top: 50% !important; margin: 0 !important;
      width: ${width}px !important; height: ${height}px !important; max-width: none !important; max-height: none !important;
      transform: translate(-50%, -50%) scale(var(--cue-s, 1)) !important; transform-origin: 50% 50% !important;
      box-sizing: border-box !important; overflow: hidden !important;
      display: block !important; visibility: visible !important;
    }
    [data-cue-on] { opacity: 1 !important; z-index: 2147483000 !important; }
    /* The slide being left, over the new one while it fades or pushes out. */
    [data-cue-leaving] { z-index: 2147483001 !important; }`}
    [data-cue-build-hidden] { visibility: hidden !important; }
  `);
  cue.layout.track(config.canvas, (scale) => document.documentElement.style.setProperty('--cue-s', String(scale)));

  function markAncestors(...shown) {
    document.querySelectorAll('[data-cue-ancestor]').forEach((element) => element.removeAttribute('data-cue-ancestor'));
    for (const slide of shown) {
      for (let node = slide.parentElement; node && node !== document.body; node = node.parentElement) {
        node.setAttribute('data-cue-ancestor', '');
      }
    }
  }

  /** Going forward plays the transition of the slide you leave; going back, the one you return to. */
  function transitionKind(previous, slide) {
    if (!previous || !animates || wholePage || cue.prefersReducedMotion()) return null;
    if (Math.abs(slide - previous.slide) !== 1) return null;
    const owner = slides[Math.min(slide, previous.slide)];
    const kind = owner && owner.getAttribute('data-cue-transition');
    if (!kind || kind === 'none') return null;
    return kind === 'push' ? 'push' : 'fade'; // Magic Move plays as a fade for now.
  }

  function playTransition(kind, from, to) {
    const leaving = slides[from];
    const entering = slides[to];
    leaving.setAttribute('data-cue-leaving', '');
    markAncestors(entering, leaving);
    const timing = { duration: kind === 'push' ? 420 : 320, easing: 'cubic-bezier(0.33, 0.01, 0.2, 1)', fill: 'forwards' };
    const animations = [];
    if (kind === 'push') {
      const direction = to > from ? 1 : -1; // `translate` composes with the pinning transform.
      animations.push(leaving.animate([{ translate: '0 0' }, { translate: `${-100 * direction}vw 0` }], timing));
      animations.push(entering.animate([{ translate: `${100 * direction}vw 0` }, { translate: '0 0' }], timing));
    } else {
      animations.push(leaving.animate([{ opacity: 1 }, { opacity: 0 }], timing));
    }
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      leaving.removeAttribute('data-cue-leaving');
      animations.forEach((animation) => animation.cancel());
      if (slides[current.slide]) markAncestors(slides[current.slide]);
      finishTransition = null;
    };
    const timer = setTimeout(finish, timing.duration + 250);
    Promise.all(animations.map((animation) => animation.finished.catch(() => null))).then(finish);
    finishTransition = finish;
  }

  function applyBuilds(slide, build) {
    document.querySelectorAll('[data-cue-build-hidden]').forEach((element) => element.removeAttribute('data-cue-build-hidden'));
    const steps = config.buildTargets[slide] || [];
    steps.forEach((selectors, index) => {
      if (index < build) return; // steps 1…build are revealed
      for (const selector of selectors) {
        document.querySelectorAll(selector).forEach((element) => element.setAttribute('data-cue-build-hidden', ''));
      }
    });
  }

  function show(position, finished) {
    const slide = cue.clamp(position.slide, 0, Math.max(0, slides.length - 1));
    const lastBuild = (config.buildTargets[slide] || []).length;
    const build = finished ? lastBuild : cue.clamp(position.build, 0, lastBuild);
    const previous = current;
    current = { slide, build };
    if (finishTransition) finishTransition();
    if (!wholePage) {
      slides.forEach((element, i) => {
        element.toggleAttribute('data-cue-on', i === slide);
        element.toggleAttribute('data-cue-off', i !== slide);
      });
      if (slides[slide]) markAncestors(slides[slide]);
      const kind = finished || !previous || previous.slide === slide ? null : transitionKind(previous, slide);
      if (kind) playTransition(kind, previous.slide, slide);
    }
    applyBuilds(slide, build);
  }

  return { name: 'generic', slideCount: Math.max(1, slides.length), slides, show, debug: () => ({ current }) };
};
