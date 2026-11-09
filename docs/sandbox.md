# Deck sandbox

Deck HTML and JavaScript are untrusted. This is what Cue enforces, how it is
tested, and what it can't stop.

## What is enforced

| Layer | Where | What it does |
|---|---|---|
| Content rules | `Sources/CueRender/Sandbox/NetworkRules.swift` | Every load is blocked except `cue-deck:`, `data:`, `blob:`, `about:` and HTTPS hosts the user allowed for this deck. The host must end the URL's authority (`https://host/`, `https://host:port/`), and any URL with userinfo (`https://allowed.example:x@evil.example/`) is blocked. Covers fetch, XHR, WebSocket, EventSource, beacons, pings, preconnect, workers, CSS and fonts. |
| Deck folder | `Serving/DeckFolder.swift`, `DeckSchemeHandler.swift` | Pages read only from the deck's folder. `..`, encoded variants, other hosts and symlinks that leave the folder get 403 or 404. `file:` is never loaded. |
| Navigation | `Sandbox/SandboxRules.swift`, `SandboxPolicy.swift` | The top frame may only show the deck's page. Frames may be inline (`srcdoc`, `about:`), from the deck folder, or from an allowed host; no `data:`, `blob:` or `file:` documents. Downloads and new windows are refused. |
| Permissions | `SandboxPolicy.swift`, `DeckGrants.permissions` | Camera, microphone and location are denied unless turned on for the deck. Notifications, clipboard reads, fullscreen and pointer lock fail. Alerts, confirms and prompts return at once. |
| Page guard | `Resources/JS/guard/page-guard.js` | Removes WebRTC and service workers before deck code runs, in every frame. WebRTC talks UDP outside WebKit's loader, so content rules can't police it. |
| Bridge isolation | `Bridge/`, `Resources/JS/bridge/` | CueBridge runs in its own content world with its own built-ins. The page can't see `window.__cue` or Cue's message handler, and poisoned prototypes in the page don't reach the bridge. |
| Hang watchdog | `Renderer/ScriptWatchdog.swift` | If a deck's script locks up the page, the surface reloads with deck scripts off. Cue's player keeps showing slides. |
| Crash recovery | `Renderer/SlideRenderer.swift` | A crashed page reloads once as it was. A second crash reloads it with deck scripts off, like a hang; after a few more the surface stops reloading. |

## Network allowance

Cue lists the hosts a deck names before it runs (`CueCore/Network/RemoteResourceScanner.swift`)
and the ones its scripts reach for while running (`75-remote-resources.js`). The deck window
asks once, grouped: "This deck loads fonts from fonts.googleapis.com and fonts.gstatic.com.
Allow?" Not now lasts until the deck closes. A running show never asks.

Allow and Never (and the camera, microphone and location switches) are saved in Cue's own
store, `~/Library/Application Support/Cue/deck-grants.json`, keyed by the deck file's path with
symlinks resolved (`CueCore/Network/DeckGrantStore.swift`). Never in `deck.cue.json`: anyone can
ship a sidecar beside a deck, so a sidecar that names hosts or permissions is ignored. Moving or
renaming a deck means it asks again. Settings › Privacy lists and revokes these choices.

Only plain host names are allowed (`fonts.gstatic.com`), never a scheme, port or path, so an
allowance can't open `http:`. Tests that need a local HTTP server pass it through
`DeckSource.insecureTestOrigins`, which is internal to CueRender. `ws:` and `wss:` URLs are
never offered in the prompt, since they stay blocked anyway. Hosts that appear only in the deck's own Content-Security-Policy
aren't asked about, because the deck may never use them.

## Tests

`Tests/CueRenderTests/SandboxTests.swift` loads `fixtures/hostile.html`, which makes about 50
attempts, including requests that put the deck's allowed host in the userinfo in front of the
server's. A local server counts every TCP connection, so "blocked" means the server saw nothing,
not that the page said so. `NetworkAllowanceTests.swift` checks that an allowed host gets
through and a different host to the same server doesn't. `SidecarGrantTests.swift` checks that a
deck shipped with a sidecar granting itself hosts and devices gets neither.

## Limits

- **The deck folder is the file's whole parent folder.** A deck opened from `~/Downloads` can
  read everything else in `~/Downloads` through `cue-deck:` URLs: its scripts can see those
  files, but can't send them anywhere unless the user allowed a host for that deck. Keep decks
  you don't trust in a folder of their own.

- **A hung page keeps burning a CPU core.** When a deck's script never yields, Cue reloads the
  surface with scripts off and the show goes on. The old web content process keeps spinning
  until Cue quits: WebKit has no public API to terminate it, and it can't process a close
  request while it is stuck.
- **Allowed hosts are HTTPS only.** `ws:`, `wss:` and plain `http:` stay blocked even for
  allowed hosts.
- **Camera and microphone need more than the per-deck flag.** The app has no usage
  descriptions yet, so macOS would refuse them even if a deck were allowed.
- **The page guard is best effort.** It runs first in every frame Cue's user scripts reach.
  A deck that finds a frame WebKit doesn't inject into could get WebRTC back. The hostile test
  tries a fresh `about:blank` iframe, and that is covered.
- **Deck scripts share the DOM with Cue's player.** A deck can't reach Cue, but it can still
  restyle or remove its own slides, which is its own content to show.
