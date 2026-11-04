// Editing a leaf element's text directly on the slide. The browser's caret
// is made transparent; Cue draws its own glowing caret natively at the rect
// reported here. The result goes back to Swift, which patches the source and
// sends the exact new content back, so the page always matches the file.

cue.inlineText = (() => {
  let editing = null; // { id, element, original, style }

  function caretRect() {
    const selection = document.getSelection();
    if (!editing || !selection || selection.rangeCount === 0) return null;
    const range = selection.getRangeAt(0);
    let rect = range.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) { // An empty element has no text to measure.
      const box = editing.element.getBoundingClientRect();
      const style = getComputedStyle(editing.element);
      const height = parseFloat(style.lineHeight) || parseFloat(style.fontSize) * 1.2 || 16;
      rect = { x: box.x, y: box.y, width: 0, height };
    }
    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height, collapsed: selection.isCollapsed };
  }

  function report(kind) {
    const rect = caretRect();
    if (rect) cue.post('textEditing', { kind, rect });
  }

  function placeCaretAtEnd(element) {
    const range = document.createRange();
    range.selectNodeContents(element);
    range.collapse(false);
    const selection = document.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
  }

  // Text boxes may hold simple formatting; anything else inside means it's a layout box.
  const INLINE = new Set(['b', 'strong', 'i', 'em', 'u', 's', 'sub', 'sup', 'span', 'font', 'br', 'a']);
  const isTextBox = (element) => Array.from(element.querySelectorAll('*')).every((child) => INLINE.has(child.localName));

  function begin(id) {
    const element = cue.sourceMap.element(id);
    if (!element || !isTextBox(element)) return false;
    if (editing) finish(true);
    editing = { id, element, original: element.innerHTML, style: element.getAttribute('style') };
    element.setAttribute('contenteditable', 'true'); // Rich, so the format bar can bold, italicise and link.
    element.style.setProperty('caret-color', 'transparent');
    element.style.setProperty('outline', 'none');
    element.addEventListener('blur', onBlur);
    element.focus();
    placeCaretAtEnd(element);
    report('caret');
    return true;
  }

  function finish(commit) {
    if (!editing) return;
    const { id, element, original, style } = editing;
    editing = null;
    element.removeEventListener('blur', onBlur);
    element.removeAttribute('contenteditable');
    if (style === null) element.removeAttribute('style');
    else element.setAttribute('style', style); // Exactly as the source wrote it.
    if (commit) {
      // Markup only when it changed: unchanged text then costs no edit at all.
      const html = element.innerHTML !== original ? element.innerHTML : null;
      cue.post('textEditing', { kind: 'commit', cueID: id, text: element.textContent, html });
    } else {
      element.innerHTML = original;
      cue.post('textEditing', { kind: 'cancel', cueID: id });
    }
  }

  const onBlur = () => finish(true);

  // Capture on window, registered before any deck script: while editing, the
  // deck's own key handlers (e.g. space for "next slide") never see the keys.
  window.addEventListener('keydown', (event) => {
    if (!editing) return;
    event.stopImmediatePropagation();
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      finish(true);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      finish(false);
    }
  }, true);
  document.addEventListener('selectionchange', () => { if (editing) report('caret'); });
  document.addEventListener('input', () => { if (editing) report('input'); }, true);

  /** Bold, italic, underline, links and line breaks in the text being edited. */
  function format(command, value) {
    if (!editing) return false;
    const done = document.execCommand(command, false, value || null);
    report('input');
    return done;
  }

  return { begin, finish, format, isTextBox, isEditing: () => editing !== null };
})();
