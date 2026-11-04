// Live web embeds in Claude Design decks.
//
// The deck stores each embed as `srcdoc` HTML in its deck-motion JSON and a
// still picture in the slide. While a slide is on screen the embed runs in a
// sandboxed iframe over the picture; when the slide leaves, the iframe goes.
// This follows the deck's own player, including its postMessage handshake.

const EMBED_FRAME_STYLE =
  'position:absolute;inset:0;width:100%;height:100%;border:0;display:block;pointer-events:none;background:transparent';
const EMBED_DEAD_STYLE =
  'position:absolute;inset:0;box-sizing:border-box;align-items:center;justify-content:center;text-align:center;' +
  'background:rgba(115,114,108,0.12);border:2px dashed rgba(115,114,108,0.4);color:#73726C;font:24px system-ui,sans-serif';

cue.createEmbeds = (motion, frameFor) => {
  let running = []; // [{ iframe, host }]

  function kill(embed, reason) {
    running = running.filter((other) => other !== embed);
    embed.iframe.remove();
    embed.host.setAttribute('data-embed-dead', '');
    const label = document.createElement('div');
    label.setAttribute('data-embed-dead-label', '');
    label.setAttribute('data-cue-owned', '');
    label.setAttribute('style', EMBED_DEAD_STYLE);
    label.textContent = reason;
    embed.host.appendChild(label);
  }

  let leaving = []; // iframes kept until the outgoing slide's transition ends

  /** The deck's still pictures say "not captured for export". On live
   *  surfaces they must never show, not even mid-transition. */
  function hidePictures() {
    for (const [slideIndex, slide] of motion.slides.entries()) {
      for (const spec of slide.embeds || []) {
        const picture = frameFor(slideIndex, spec.id)?.firstElementChild;
        if (picture) {
          picture.setAttribute('data-embed-under', '');
          picture.setAttribute('data-embed-pic', '');
        }
      }
    }
  }

  function start(slideIndex) {
    if (!motion.live) return;
    const specs = (motion.slides[slideIndex] && motion.slides[slideIndex].embeds) || [];
    for (const spec of specs) {
      const host = frameFor(slideIndex, spec.id);
      if (!host || host.hasAttribute('data-embed-dead')) continue;
      if (running.some((embed) => embed.host === host)) continue;
      dropLeaving(host);

      const iframe = document.createElement('iframe');
      iframe.setAttribute('sandbox', 'allow-scripts');
      iframe.setAttribute('data-cue-owned', ''); // Created by Cue, not in the source.
      iframe.setAttribute('inert', '');
      iframe.setAttribute('tabindex', '-1');
      iframe.setAttribute('referrerpolicy', 'no-referrer');
      iframe.setAttribute('title', 'Embedded web content (sandboxed)');
      iframe.setAttribute('style', EMBED_FRAME_STYLE);

      const embed = { iframe, host, loads: 0 };
      iframe.addEventListener('load', () => {
        embed.loads += 1;
        if (embed.loads > 1) kill(embed, 'Web embed disabled. It navigated away from its content.');
      });
      iframe.srcdoc = spec.srcdoc;
      running.push(embed);
      host.appendChild(iframe);
    }
  }

  /** Stops the running embeds. `afterMs` keeps them on screen while the
   *  outgoing slide fades or pushes out, so nothing pops mid-transition. */
  function stop(afterMs = 0) {
    const outgoing = running;
    running = [];
    if (afterMs <= 0) {
      outgoing.forEach((embed) => embed.iframe.remove());
      return;
    }
    leaving.push(...outgoing);
    setTimeout(() => {
      outgoing.forEach((embed) => embed.iframe.remove());
      leaving = leaving.filter((embed) => !outgoing.includes(embed));
    }, afterMs);
  }

  /** Coming straight back to a slide: drop its outgoing copy now. */
  function dropLeaving(host) {
    for (const embed of leaving.filter((candidate) => candidate.host === host)) embed.iframe.remove();
    leaving = leaving.filter((embed) => embed.host !== host);
  }

  window.addEventListener('message', (event) => {
    const embed = running.find((candidate) => candidate.iframe.contentWindow === event.source);
    if (!embed || event.origin !== 'null') return;
    const data = event.data;
    if (typeof data !== 'object' || data === null) return;
    if (data.type === 'appifact-embed:navigating') {
      kill(embed, 'Web embed disabled. It navigated away from its content.');
    } else if (data.type === 'appifact-embed:ready' && embed.iframe.contentWindow) {
      const update = { type: 'appifact-embed:update', t: 0, playing: false, selected: false, props: {} };
      embed.iframe.contentWindow.postMessage(update, '*');
    }
  });

  /** Slide indexes that have at least one embed. */
  const slidesWithEmbeds = () =>
    motion.slides.map((slide, i) => ((slide.embeds || []).length > 0 ? i : -1)).filter((i) => i >= 0);

  return { start, stop, hidePictures, slidesWithEmbeds, runningCount: () => running.length };
};
