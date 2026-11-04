// Player for every other deck Cue understands (Cue's own convention,
// reveal.js markup, role-tagged pages, top-level sections).
//
// It shows one slide element, pinned to the window centre and scaled from
// its design canvas, over a black backdrop. Build steps hide their target
// elements until the step is reached.

cue.createGenericPlayer = (config) => {
  const slides = Array.from(document.querySelectorAll(config.slideSelector));
  const wholePage = slides.length === 1 && (slides[0] === document.body || slides[0] === document.documentElement);
  const { width, height } = config.canvas;
  let current = null;

  cue.setStyle('cue-generic-player', `
    html, body { overflow: hidden !important; background: #000 !important; }
    ${wholePage ? '' : `
    body::before { content: ''; position: fixed; inset: 0; background: #000; z-index: 2147482999; }
    [data-cue-off] { display: none !important; }
    [data-cue-ancestor] { transform: none !important; filter: none !important; perspective: none !important;
      contain: none !important; overflow: visible !important; }
    [data-cue-on] {
      position: fixed !important; left: 50% !important; top: 50% !important; margin: 0 !important;
      width: ${width}px !important; height: ${height}px !important; max-width: none !important; max-height: none !important;
      transform: translate(-50%, -50%) scale(var(--cue-s, 1)) !important; transform-origin: 50% 50% !important;
      box-sizing: border-box !important; overflow: hidden !important; z-index: 2147483000 !important;
      display: block !important; visibility: visible !important; opacity: 1 !important;
    }`}
    [data-cue-build-hidden] { visibility: hidden !important; }
  `);
  cue.layout.track(config.canvas, (scale) => document.documentElement.style.setProperty('--cue-s', String(scale)));

  function markAncestors(slide) {
    document.querySelectorAll('[data-cue-ancestor]').forEach((element) => element.removeAttribute('data-cue-ancestor'));
    for (let node = slide.parentElement; node && node !== document.body; node = node.parentElement) {
      node.setAttribute('data-cue-ancestor', '');
    }
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
    current = { slide, build };
    if (!wholePage) {
      slides.forEach((element, i) => {
        element.toggleAttribute('data-cue-on', i === slide);
        element.toggleAttribute('data-cue-off', i !== slide);
      });
      if (slides[slide]) markAncestors(slides[slide]);
    }
    applyBuilds(slide, build);
  }

  return { name: 'generic', slideCount: Math.max(1, slides.length), slides, show, debug: () => ({ current }) };
};
