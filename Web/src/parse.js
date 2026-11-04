// Parses HTML with parse5 and returns a compact JSON element tree with
// exact source offsets (UTF-16 indices, the same as JS string indices).
// Runs inside a bare JavaScriptCore context: no DOM, no native bindings.
import { parse } from 'parse5';

const TEXT_CAP = 2000;
// Elements whose *deep* text adapters need (labels, notes, titles).
const DEEP_TEXT_TAGS = new Set(['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'aside', 'title', 'figcaption']);

function directText(node) {
  let text = '';
  for (const child of node.childNodes || []) {
    if (child.nodeName === '#text') text += child.value;
    if (text.length > TEXT_CAP) break;
  }
  return text.trim().slice(0, TEXT_CAP);
}

function deepText(node) {
  let text = '';
  const walk = (n) => {
    if (text.length > TEXT_CAP) return;
    if (n.nodeName === '#text') text += n.value;
    for (const c of n.childNodes || []) walk(c);
  };
  walk(node);
  return text.replace(/\s+/g, ' ').trim().slice(0, TEXT_CAP);
}

function range(loc) {
  return loc ? [loc.startOffset, loc.endOffset] : null;
}

// Short keys keep the JSON small for large decks:
// t tag, a attrs, ar attr ranges, r element range, s start tag range, x text, c children.
function convert(node) {
  const loc = node.sourceCodeLocation;
  const attrs = {};
  const attrRanges = {};
  for (const { name, value } of node.attrs || []) {
    attrs[name] = value;
    const attrLoc = loc && loc.attrs && loc.attrs[name];
    if (attrLoc) attrRanges[name] = range(attrLoc);
  }
  const children = [];
  const kids = node.nodeName === 'template' && node.content ? node.content.childNodes : node.childNodes;
  for (const child of kids || []) {
    if (child.tagName) children.push(convert(child));
  }
  return {
    t: node.tagName,
    a: attrs,
    ar: attrRanges,
    r: range(loc),
    s: loc ? range(loc.startTag) : null,
    x: DEEP_TEXT_TAGS.has(node.tagName) ? deepText(node) : directText(node),
    c: children,
  };
}

globalThis.cueParse = function cueParse(html) {
  const document = parse(html, { sourceCodeLocationInfo: true });
  const root = document.childNodes.find((n) => n.tagName === 'html');
  return JSON.stringify(convert(root));
};
