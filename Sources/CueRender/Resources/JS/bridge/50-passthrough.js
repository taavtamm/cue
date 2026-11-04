// Passthrough: the deck's own script stays in charge.
//
// Used for HTML decks Cue doesn't recognise. Cue forwards navigation as key
// presses the deck already understands, and reports back which slide the
// page is showing so the presenter view can follow.

const KEY_CODES = { ArrowRight: 39, ArrowLeft: 37, Home: 36 };

cue.createPassthroughPlayer = (config) => {
  const slides = () => Array.from(document.querySelectorAll(config.slideSelector));
  let commanded = null;
  let reported = -1;

  /** The slide the page is showing: one marked current, else the most visible. */
  function visibleIndex() {
    const list = slides();
    if (list.length <= 1) return 0;
    const marked = list.findIndex((element) =>
      element.classList.contains('present') || element.classList.contains('active') ||
      element.getAttribute('aria-current') === 'true');
    if (marked >= 0) return marked;

    let best = 0;
    let bestArea = 0;
    list.forEach((element, i) => {
      const style = getComputedStyle(element);
      if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) < 0.05) return;
      const r = element.getBoundingClientRect();
      const w = Math.max(0, Math.min(r.right, innerWidth) - Math.max(r.left, 0));
      const h = Math.max(0, Math.min(r.bottom, innerHeight) - Math.max(r.top, 0));
      if (w * h > bestArea) {
        best = i;
        bestArea = w * h;
      }
    });
    return best;
  }

  function report() {
    const index = visibleIndex();
    if (index === reported) return;
    reported = index;
    cue.post('position', { slide: index, build: 0 });
  }

  let reportQueued = false;
  function reportSoon() {
    if (reportQueued) return;
    reportQueued = true;
    setTimeout(() => {
      reportQueued = false;
      report();
    }, 60);
  }

  const watched = ['class', 'style', 'hidden', 'aria-hidden', 'aria-current', 'data-off'];
  new MutationObserver(reportSoon).observe(document.documentElement, {
    attributes: true, subtree: true, attributeFilter: watched,
  });
  window.addEventListener('scroll', reportSoon, true);
  window.addEventListener('hashchange', reportSoon);
  window.addEventListener('transitionend', reportSoon, true);

  function press(key) {
    const keyCode = KEY_CODES[key];
    const target = document.activeElement || document.body;
    for (const type of ['keydown', 'keyup']) {
      target.dispatchEvent(new KeyboardEvent(type, { key, code: key, keyCode, which: keyCode, bubbles: true, cancelable: true }));
    }
  }

  function show(position) {
    const from = commanded || { slide: Math.max(0, reported), build: 0 };
    commanded = position;
    const forward = position.slide > from.slide || (position.slide === from.slide && position.build > from.build);
    const backward = position.slide < from.slide || (position.slide === from.slide && position.build < from.build);
    if (Math.abs(position.slide - from.slide) > 1) {
      press('Home');
      for (let i = 0; i < position.slide; i++) press('ArrowRight');
    } else if (forward) {
      press('ArrowRight');
    } else if (backward) {
      press('ArrowLeft');
    }
    reportSoon();
  }

  reportSoon();
  return { name: 'passthrough', slideCount: Math.max(1, slides().length), slides: slides(), show, debug: () => ({ reported }) };
};
