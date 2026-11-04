// Applies source edits to the live page without a reload. Each change says
// exactly what the new source contains, so the page matches a fresh load.

cue.domEdits = (() => {
  const OVERRIDES_ID = 'cue-overrides';

  function overridesBlock() {
    let block = document.getElementById(OVERRIDES_ID);
    if (!block) {
      block = document.createElement('style');
      block.id = OVERRIDES_ID;
      (document.head || document.documentElement).appendChild(block);
    }
    return block;
  }

  function apply(change) {
    if (change.type === 'setOverrides') {
      overridesBlock().textContent = change.css;
      return true;
    }
    const element = cue.sourceMap.element(change.cueID);
    if (!element) return false;
    if (change.type === 'setInnerHTML') {
      element.innerHTML = change.html;
    } else if (change.type === 'setAttribute') {
      if (change.value === null || change.value === undefined) element.removeAttribute(change.name);
      else element.setAttribute(change.name, change.value);
    } else {
      return false;
    }
    return true;
  }

  /** Returns how many changes found their element. */
  const applyAll = (changes) => changes.filter(apply).length;

  return { applyAll };
})();
