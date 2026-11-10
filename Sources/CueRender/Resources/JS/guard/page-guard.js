// Runs in the deck's own world, in every frame, before the deck's scripts.
// Removes network paths that WebKit's content rules don't cover. Deck code
// runs after this and can't get the originals back from this frame.
(function () {
  'use strict';
  const remove = (owner, name) => {
    try {
      Object.defineProperty(owner, name, { value: undefined, writable: false, configurable: false });
    } catch (e) {
      /* Already locked down. */
    }
  };
  // WebRTC: ICE gathering talks to STUN/TURN servers directly.
  for (const name of ['RTCPeerConnection', 'webkitRTCPeerConnection', 'RTCDataChannel', 'RTCIceCandidate',
                      'RTCSessionDescription', 'RTCRtpSender', 'RTCRtpReceiver', 'RTCRtpTransceiver']) {
    remove(window, name);
  }
  // Workers would get a fresh global scope with WebRTC-free but fetch-capable
  // contexts; their loads still go through the content rules, so they stay.
  if (window.navigator && 'serviceWorker' in window.navigator) remove(Navigator.prototype, 'serviceWorker');
  // Counts the deck's own redraw requests, so Cue can tell a deck that
  // repaints every frame from one that settles. Main frame only; the
  // count is read through window events (Cue's bridge runs in another world).
  if (window.top === window && typeof window.requestAnimationFrame === 'function') {
    const original = window.requestAnimationFrame;
    let requests = 0;
    window.requestAnimationFrame = function (callback) {
      requests += 1;
      return original.call(window, callback);
    };
    window.addEventListener('cue-frame-requests?', () => {
      window.dispatchEvent(new CustomEvent('cue-frame-requests', { detail: requests }));
    });
  }
})();
