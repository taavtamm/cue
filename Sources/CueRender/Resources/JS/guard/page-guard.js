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
})();
