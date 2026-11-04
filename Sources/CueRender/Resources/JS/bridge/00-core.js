// CueBridge core: message plumbing between Cue and the page.
// Runs in Cue's isolated content world. The deck's own scripts share the
// DOM with us but cannot see these variables or call Cue's handler.

const cue = (window.__cue = {});

/** Command handlers, keyed by command type. Filled in by later files. */
cue.handlers = {};

cue.post = (type, payload = {}) => {
  window.webkit.messageHandlers.cue.postMessage(Object.assign({ type }, payload));
};

cue.reportError = (error) => {
  cue.post('error', { message: String((error && error.stack) || error) });
};

/** Entry point for every command Swift sends. */
cue.receive = (command) => {
  const handler = cue.handlers[command.type];
  if (!handler) return cue.reportError('Unknown bridge command: ' + command.type);
  try {
    handler(command);
  } catch (error) {
    cue.reportError(error);
  }
};

cue.clamp = (value, low, high) => Math.max(low, Math.min(high, value));

cue.prefersReducedMotion = () =>
  typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches;

/** Adds or replaces a <style> element Cue owns. */
cue.setStyle = (id, css) => {
  let style = document.getElementById(id);
  if (!style) {
    style = document.createElement('style');
    style.id = id;
    document.documentElement.appendChild(style);
  }
  style.textContent = css;
};
