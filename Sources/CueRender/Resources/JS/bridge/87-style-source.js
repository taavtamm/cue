// Where an element's value for one CSS property comes from: its inline
// style, Cue's override block, a deck stylesheet rule, an ancestor, or the
// browser default. Read-only: Cue never writes to the deck's stylesheets.
//
// The cascade is approximated: !important, then specificity, then order.
// Cascade layers and shadow DOM are not modelled.

cue.styleSource = (() => {
  /** [ids, classes/attributes/pseudo-classes, types/pseudo-elements] of one selector. */
  function specificity(selector) {
    let text = selector.replace(/:where\([^)]*\)/g, '');
    text = text.replace(/:(?:is|not|has)\(([^)]*)\)/g, ' $1 '); // Approximation: count the argument.
    text = text.replace(/"[^"]*"|'[^']*'/g, '');
    const ids = (text.match(/#[\w-]+/g) || []).length;
    const classes = (text.match(/\.[\w-]+|\[[^\]]*\]|:(?!:)[\w-]+/g) || []).length;
    const types = (text.replace(/#[\w-]+|\.[\w-]+|\[[^\]]*\]|:+[\w-]+/g, ' ').match(/(^|[\s>+~(])[a-zA-Z][\w-]*/g) || []).length
      + (text.match(/::[\w-]+/g) || []).length;
    return [ids, classes, types];
  }

  const compare = (a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2];

  /** The most specific selector in a list that matches the element. */
  function bestMatch(element, selectorText) {
    let best = null;
    for (const selector of splitSelectors(selectorText)) {
      let matches = false;
      try { matches = element.matches(selector); } catch (error) { matches = false; }
      if (matches) {
        const value = specificity(selector);
        if (!best || compare(value, best.specificity) > 0) best = { selector, specificity: value };
      }
    }
    return best;
  }

  function splitSelectors(text) {
    const parts = [];
    let depth = 0;
    let start = 0;
    for (let i = 0; i < text.length; i += 1) {
      const c = text[i];
      if (c === '(' || c === '[') depth += 1;
      else if (c === ')' || c === ']') depth -= 1;
      else if (c === ',' && depth === 0) { parts.push(text.slice(start, i).trim()); start = i + 1; }
    }
    parts.push(text.slice(start).trim());
    return parts.filter(Boolean);
  }

  function collect(element, property, rules, sheet, sheetIndex, out) {
    for (const rule of rules) {
      if (rule.type === CSSRule.MEDIA_RULE && !matchMedia(rule.media.mediaText).matches) continue;
      if (rule.type === CSSRule.SUPPORTS_RULE && !CSS.supports(rule.conditionText)) continue;
      if (rule.selectorText !== undefined && rule.style) {
        const value = rule.style.getPropertyValue(property);
        const match = value ? bestMatch(element, rule.selectorText) : null;
        if (match) {
          out.push({ value, important: rule.style.getPropertyPriority(property) === 'important',
            specificity: match.specificity, order: out.length, selector: rule.selectorText, sheet, sheetIndex });
        }
      }
      if (rule.cssRules) collect(element, property, rule.cssRules, sheet, sheetIndex, out);
    }
  }

  function describe(sheet) {
    const owner = sheet.ownerNode;
    if (!owner) return 'stylesheet';
    if (owner.localName === 'link') return owner.getAttribute('href') || 'linked stylesheet';
    return owner.id ? '<style id="' + owner.id + '">' : '<style>';
  }

  function winner(element, property) {
    const candidates = [];
    let unreadable = 0;
    Array.from(document.styleSheets).forEach((sheet, index) => {
      let rules = null;
      try { rules = sheet.cssRules; } catch (error) { unreadable += 1; }
      if (rules) collect(element, property, rules, sheet, index, candidates);
    });
    candidates.sort((a, b) => (a.important - b.important) || compare(a.specificity, b.specificity) || a.order - b.order);
    return { rule: candidates[candidates.length - 1] || null, unreadable };
  }

  function source(cueID, property) {
    const element = cue.sourceMap.element(cueID);
    if (!element) return null;
    const computed = getComputedStyle(element).getPropertyValue(property).trim();
    const inline = element.style.getPropertyValue(property);
    const inlineImportant = element.style.getPropertyPriority(property) === 'important';
    const { rule, unreadable } = winner(element, property);
    const base = { property, computed, unreadableSheets: unreadable };
    if (inline && (inlineImportant || !rule || !rule.important)) {
      return Object.assign(base, { origin: 'inline', value: inline });
    }
    if (rule) {
      const isOverride = rule.sheet.ownerNode && rule.sheet.ownerNode.id === 'cue-overrides';
      return Object.assign(base, { origin: isOverride ? 'cueOverrides' : 'stylesheet', value: rule.value,
        selector: rule.selector, sheetIndex: rule.sheetIndex, sheet: describe(rule.sheet) });
    }
    const parent = element.parentElement;
    if (parent && getComputedStyle(parent).getPropertyValue(property).trim() === computed) {
      return Object.assign(base, { origin: 'inherited', value: computed, from: cue.sourceMap.idOf(parent) });
    }
    return Object.assign(base, { origin: 'default', value: computed });
  }

  return { source, specificity };
})();
