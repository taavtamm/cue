// Player for Claude Design decks (hz:* meta tags + a deck-motion JSON block).
//
// Cue serves these decks without their own player script and drives them
// with this one instead. It reuses the deck's CSS hooks so the slides look
// exactly as the author's player made them:
//   html.deck-js.deck-stage   one slide at a time, stacked full-window
//   --deck-s                  scale of the 1920×1080 canvas
//   [data-off]                slides that aren't showing
//   [data-build-hidden]       build items not yet revealed

cue.createClaudeDesignPlayer = (config) => {
  const motion = JSON.parse(document.getElementById('deck-motion').textContent);
  const root = document.documentElement;
  const slides = Array.from(document.querySelectorAll(config.slideSelector));
  const frames = slides.map((slide) => slide.querySelector('.deck-scaler > *') || slide);
  const frameFor = (i, id) => frames[i].querySelector('[data-frame-id="' + CSS.escape(id) + '"]');
  const framesOf = (i) => Array.from(frames[i].querySelectorAll('[data-frame-id]'));
  const stepsOf = (i) => (motion.slides[i] ? motion.slides[i].steps : []);
  const lastStep = (i) => Math.max(0, stepsOf(i).length - 1);

  const embeds = cue.createEmbeds(motion, frameFor);
  const runsEmbeds = config.surface !== 'thumbnail' && config.surface !== 'export';
  const animates = ['stage', 'mirror', 'presenterCurrent', 'editor'].includes(config.surface);

  let current = null; // { slide, build }
  let buildAnimations = [];
  let finishTransition = null;
  let autoStepTimer = 0;

  root.classList.add('deck-js', 'deck-stage');
  cue.layout.track(config.canvas, (scale) => root.style.setProperty('--deck-s', String(scale)));

  function applyBuildState(i, step) {
    const hidden = stepsOf(i)[step] ? stepsOf(i)[step].hidden : [];
    for (const element of framesOf(i)) {
      element.toggleAttribute('data-build-hidden', hidden.includes(element.getAttribute('data-frame-id') || ''));
    }
  }

  function animateStep(i, step) {
    const events = stepsOf(i)[step] ? stepsOf(i)[step].events : [];
    for (const event of events) {
      const element = frameFor(i, event.id);
      const effect = motion.effects[event.effect];
      if (!element || !effect || typeof element.animate !== 'function') continue;
      const base = element.style.transform && element.style.transform !== 'none' ? element.style.transform : '';
      const away = { transform: (base + ' ' + effect.transform).trim() || 'none', opacity: 0 };
      const home = { transform: base || 'none', opacity: 1 };
      element.removeAttribute('data-build-hidden');
      if (event.dir === 'in') {
        buildAnimations.push(element.animate([away, home], { duration: motion.buildMs, easing: effect.easing }));
      } else {
        const exit = element.animate([home, away], { duration: motion.buildMs, easing: motion.exitEasing });
        exit.finished.then(() => element.setAttribute('data-build-hidden', ''), () => {});
        buildAnimations.push(exit);
      }
    }
  }

  /** Going forward plays the transition of the slide you leave; going back, the one you return to. */
  function transitionKind(previous, slide) {
    if (!previous || !animates || cue.prefersReducedMotion()) return null;
    if (Math.abs(slide - previous.slide) !== 1) return null;
    const owner = motion.slides[Math.min(slide, previous.slide)];
    const kind = owner && owner.transition;
    if (!kind) return null;
    return kind === 'push' ? 'push' : 'fade'; // Magic Move is not in v1; it falls back to a fade.
  }

  function playTransition(kind, from, to) {
    const leaving = slides[from];
    const duration = motion.transMs[kind] || motion.transMs.fade || 0;
    const timing = { duration, easing: motion.transEase, fill: 'forwards' };
    const animations = [];
    leaving.removeAttribute('data-off');
    leaving.setAttribute('data-leaving', '');
    if (kind === 'push') {
      const shift = (to > from ? 1 : -1) * config.canvas.width;
      animations.push(frames[from].animate([{ transform: 'none' }, { transform: `translateX(${-shift}px)` }], timing));
      animations.push(frames[to].animate([{ transform: `translateX(${shift}px)` }, { transform: 'none' }], timing));
    } else {
      animations.push(leaving.animate([{ opacity: 1 }, { opacity: 0 }], timing));
    }
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      leaving.setAttribute('data-off', '');
      leaving.removeAttribute('data-leaving');
      animations.forEach((animation) => animation.cancel());
      finishTransition = null;
    };
    const timer = setTimeout(finish, duration + 250);
    Promise.all(animations.map((animation) => animation.finished.catch(() => null))).then(finish);
    finishTransition = finish;
  }

  function showOnly(slide) {
    slides.forEach((element, i) => {
      const on = i === slide;
      element.toggleAttribute('data-off', !on);
      element.toggleAttribute('inert', !on);
      if (on) element.removeAttribute('aria-hidden');
      else element.setAttribute('aria-hidden', 'true');
    });
  }

  /** Auto builds advance on their own. The stage asks Swift, which stays the one source of truth. */
  function scheduleAutoStep(previous, finished) {
    if (finished || config.surface !== 'stage') return;
    const next = current.build + 1;
    const step = stepsOf(current.slide)[next];
    if (!step || !step.auto) return;
    const delay = previous && previous.slide === current.slide ? motion.buildMs + 140 : 600;
    const from = current;
    autoStepTimer = setTimeout(() => {
      if (current === from) cue.post('position', { slide: from.slide, build: next });
    }, delay);
  }

  function show(position, finished) {
    const slide = cue.clamp(position.slide, 0, slides.length - 1);
    const build = finished ? lastStep(slide) : cue.clamp(position.build, 0, lastStep(slide));
    const previous = current;
    current = { slide, build };
    buildAnimations.forEach((animation) => animation.cancel());
    buildAnimations = [];
    if (finishTransition) finishTransition();
    clearTimeout(autoStepTimer);

    if (!previous || previous.slide !== slide) {
      embeds.stop();
      showOnly(slide);
      applyBuildState(slide, build);
      const kind = finished ? null : transitionKind(previous, slide);
      if (kind) playTransition(kind, previous.slide, slide);
      if (runsEmbeds) embeds.start(slide);
    } else {
      applyBuildState(slide, build);
      const oneStepOn = build === previous.build + 1;
      if (!finished && animates && oneStepOn && !cue.prefersReducedMotion()) animateStep(slide, build);
    }
    scheduleAutoStep(previous, finished);
  }

  return {
    name: 'claudeDesign',
    slideCount: slides.length,
    slides,
    show,
    liveSlides: embeds.slidesWithEmbeds,
    debug: () => ({ current, embeds: embeds.runningCount() }),
  };
};
