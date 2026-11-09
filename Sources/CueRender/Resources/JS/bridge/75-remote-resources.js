// Remote resources: tell Swift which network hosts the page reaches for.
//
// Every http(s) load is blocked unless the user allowed the host, so the
// deck window can ask "This deck loads fonts from … Allow?". Swift's static
// scan covers the HTML as written; this covers what scripts add later and
// what CSS pulls in. We only read URLs here; nothing is fetched.

(function watchRemoteResources() {
  const seen = new Set(); // "host|kind"
  let pending = [];
  let timer = 0;

  function hostOf(value) {
    try {
      const url = new URL(String(value).trim(), document.baseURI);
      // Not ws: or wss:, which stay blocked even for allowed hosts, so there's nothing to ask.
      return /^https?:$/.test(url.protocol) ? url.hostname.toLowerCase() : null;
    } catch (error) {
      return null;
    }
  }

  function note(value, kind) {
    const host = hostOf(value);
    if (!host) return;
    const key = host + '|' + kind;
    if (seen.has(key)) return;
    seen.add(key);
    pending.push({ host, kind });
    clearTimeout(timer);
    timer = setTimeout(flush, 300);
  }

  function flush() {
    if (pending.length === 0) return;
    cue.post('remoteResources', { resources: pending });
    pending = [];
  }

  function kindOf(element) {
    switch (element.localName) {
      case 'script': return 'scripts';
      case 'img': case 'picture': return 'images';
      case 'video': case 'audio': case 'track': case 'source': return 'media';
      case 'iframe': case 'frame': case 'object': case 'embed': return 'frames';
      case 'link': {
        const rel = (element.getAttribute('rel') || '').toLowerCase();
        if (rel.includes('stylesheet')) return 'styles';
        if (rel.includes('icon')) return 'images';
        return element.getAttribute('as') === 'font' ? 'fonts' : 'other';
      }
      default: return 'other';
    }
  }

  const URL_IN_CSS = /url\(\s*['"]?([^'")\s]+)/g;

  function noteCSS(text, kind) {
    for (const match of String(text).matchAll(URL_IN_CSS)) note(match[1], kind);
  }

  function scanElement(element) {
    if (element.localName === 'a') return; // Links don't load until clicked.
    for (const name of ['src', 'href', 'data', 'poster']) {
      if (element.hasAttribute(name)) note(element.getAttribute(name), kindOf(element));
    }
    const srcset = element.getAttribute('srcset');
    if (srcset) for (const part of srcset.split(',')) note(part.trim().split(/\s+/)[0], 'images');
    const style = element.getAttribute('style');
    if (style && style.includes('url(')) noteCSS(style, 'images');
  }

  function scanStyleSheets() {
    for (const sheet of Array.from(document.styleSheets)) {
      let rules;
      try {
        rules = sheet.cssRules; // Throws for cross-origin sheets; those were blocked anyway.
      } catch (error) {
        continue;
      }
      for (const rule of Array.from(rules || [])) {
        if (rule.type === CSSRule.IMPORT_RULE) note(rule.href, 'styles');
        else if (rule.type === CSSRule.FONT_FACE_RULE) noteCSS(rule.style.getPropertyValue('src'), 'fonts');
        else if (rule.cssText.includes('url(')) noteCSS(rule.cssText, 'images');
      }
    }
  }

  function scanTree(root) {
    if (root.nodeType !== Node.ELEMENT_NODE) return;
    scanElement(root);
    for (const element of Array.from(root.querySelectorAll('[src],[href],[srcset],[data],[poster],[style]'))) {
      scanElement(element);
    }
  }

  scanTree(document.documentElement);
  scanStyleSheets();

  new MutationObserver((records) => {
    let styles = false;
    for (const record of records) {
      if (record.type === 'attributes') scanElement(record.target);
      for (const node of Array.from(record.addedNodes)) {
        scanTree(node);
        if (node.localName === 'style' || node.localName === 'link') styles = true;
      }
    }
    if (styles) scanStyleSheets();
  }).observe(document.documentElement, {
    subtree: true, childList: true, attributes: true,
    attributeFilter: ['src', 'href', 'srcset', 'data', 'poster', 'style'],
  });

  // Loads that failed (blocked loads end here) and the deck's own CSP refusals.
  window.addEventListener('error', (event) => {
    if (event.target && event.target !== window && event.target.nodeType === Node.ELEMENT_NODE) {
      scanElement(event.target);
    }
  }, true);
  document.addEventListener('securitypolicyviolation', (event) => note(event.blockedURI, 'other'));
})();
