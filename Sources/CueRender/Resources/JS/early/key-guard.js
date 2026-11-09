// Runs in Cue's bridge world at document start, before any deck script, so
// this capture listener on window is the first one there. While text is
// being edited on the slide, 89-inline-text.js takes the key here and the
// deck's own handlers (e.g. space for "next slide") never see it.
(function () {
  'use strict';
  window.addEventListener('keydown', (event) => {
    const inline = window.__cue && window.__cue.inlineText;
    if (inline) inline.handleKey(event);
  }, true);
})();
