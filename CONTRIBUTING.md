# Working on Cue

## Layout

| Path | What lives there | May import |
|---|---|---|
| `Sources/CueCore` | Deck model, adapters, parse5 bridge, show state, sidecar | Foundation, JavaScriptCore |
| `Sources/CueRender` | WKWebView surfaces, CueBridge JS, scheme handler, sandbox rules | CueCore, WebKit, AppKit |
| `Sources/CueUI` | Shared design-system components (glass, glow, caret, buttons) | SwiftUI, AppKit |
| `Sources/CueEditor` | The editor's state and logic: session, selection, inspector values, timeline, thumbnails, Claude's change sets | CueCore, CueRender, AppKit |
| `Sources/CueImport` | PowerPoint, Keynote, OpenDocument and PDF import | CueCore, CoreGraphics, ImageIO |
| `Sources/CueMCP` | Cue's MCP server: tools, resources, change sets over a `DeckHost`, the Unix-socket listener (docs/mcp.md) | CueCore, MCP |
| `Sources/cue-mcp` | The helper Claude starts: pipes stdio to Cue's socket | Foundation |
| `App/Sources` | Windows and screens that compose the modules | everything |
| `Web/` | Build scripts for bundled JS (parse5) | — |
| `fixtures/` | Test decks. Never edit `demo-deck.html`; tests copy it. | — |

The data contracts are `Sources/CueCore/Model/*` and
`Sources/CueRender/Bridge/BridgeProtocol.swift`. Change them deliberately.

## Rules

- One type per file. Files stay under 300 lines; SwiftLint enforces it.
- Screens compose `CueUI` components. Don't restyle glass, glow or carets inline.
- `CueCore` never imports AppKit, SwiftUI or WebKit, so its tests run headless.
- Deck JavaScript only ever runs inside WKWebView. JavaScriptCore is used for
  parse5 only and has no native bindings.
- Name things for what they do. Prefer a short comment on *why* over *what*.

## Build and test

```sh
swift build && swift test          # core, render and UI modules
xcodegen && open Cue.xcodeproj     # the app
```
