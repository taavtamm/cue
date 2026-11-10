<p align="center"><img src="docs/icon/renditions.png" alt="Cue's app icon at several sizes" width="640"></p>

# Cue

Cue is a native macOS app for presenting and editing HTML presentations. It opens
the deck you already have, plays it on as many screens as you connect, and lets you
edit it by hand or with your own Claude agent, writing small, exact changes back to
the HTML file.

- **Opens HTML decks as they are.** Cue understands Claude Design decks, reveal.js,
  its own convention, and decks built from `<section>` elements or ARIA slides. Any
  other HTML page plays with its own scripts.
- **Opens other formats too.** PowerPoint (`.pptx`) imports directly. Keynote, `.ppt`,
  OpenDocument and PDF are converted with Keynote's help when it's installed. Imports
  become editable HTML, and the original stays beside them.
- **Presents on every screen.** Each display gets a role: stage, mirror, presenter
  view or off. There's a rehearsal mode, live embeds, and animations kept in step
  across screens.
- **Edits like a slide app.** Change text and fonts, add text boxes, images and shapes,
  then move, resize and reorder them. Speaker notes, builds and transitions are
  editable too, and there's undo for everything. Saving changes only the parts you
  edited; the rest of the file stays byte-for-byte as it was.
- **Works with Claude, on your own plan.** Cue runs a local MCP server. Claude Code
  or Claude Desktop connects to it and can edit, restyle or rebuild the deck while you
  watch. Cue never signs in to Claude itself.
- **Warns about heavy decks.** Cue measures what keeps the GPU busy as slides play
  (blurs over moving content, endless animations, embeds, scripts redrawing every
  frame) and hands you a prompt so your AI can make the deck lighter. Live slides
  pause while Cue is in the background.
- **Exports** to editable PowerPoint (text, pictures and simple shapes stay editable;
  animations become static), PDF, or one PNG per slide.
- **Keeps decks contained.** Deck JavaScript runs only inside WebKit, can read only
  its own folder, and gets no network access unless you allow it for that deck.
  See [docs/sandbox.md](docs/sandbox.md).

## Requirements

- macOS 27 or later
- Xcode 27 (Swift 6.2 or later)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

Node is needed only to rebuild the bundled parse5 parser (see [Web/README.md](Web/README.md)).

## Build and run

```sh
git clone https://github.com/taavtamm/cue.git
cd cue
xcodegen generate
xcodebuild -project Cue.xcodeproj -scheme Cue -configuration Release \
  -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Release/Cue.app
```

To keep the app, copy `Cue.app` to `/Applications`. To work on it in Xcode, run
`xcodegen generate && open Cue.xcodeproj` and use the Cue scheme.

The build is signed ad hoc, so it runs on the Mac that built it. Cue's Focus
warning before a show needs a signing team with the Communication Notifications
entitlement; without one, the warning is simply skipped.

## Connect Claude

Cue's MCP server listens on a Unix socket that only your user can open. Claude
reaches it through the `cue-mcp` helper inside the app.

**Claude Code:**

```sh
claude mcp add cue -- "/Applications/Cue.app/Contents/MacOS/cue-mcp"
```

**Claude Desktop:** go to Cue › Settings › Claude › Add to Claude Desktop, then
restart Claude Desktop.

The first time a client connects, Cue asks you to allow it. After that, ask
Claude something like "make slide 3's headline shorter" or "redesign this deck
in a dark theme". Each edit appears on the slide right away and is one undoable
change, and nothing is saved until you save. The Ask bar under the slide shows
what Claude is doing.

[docs/mcp.md](docs/mcp.md) lists every tool and explains how change sets work.

## Keyboard

| Keys | Action |
|---|---|
| ⌘N / ⌘O / ⌘S | New presentation, open, save |
| ⌥⌘P | Play slideshow |
| ⌥⌘R | Rehearse on this Mac |
| ⌥⌘D | Displays |
| ⌘E | Export |
| ↑ ↓ | Previous or next slide in the editor |
| → ↓ Space / ← ↑ | Next or previous build while presenting |
| B / W | Black or white screen while presenting |
| *number* Return | Jump to that slide while presenting |
| Esc | End the show |

## Tests

```sh
swift build && swift test
```

The tests run without a screen: web views render offscreen and nothing takes
over your displays. The decks they use are in `fixtures/`; tests work on copies.

## Project layout

Testable code lives in a Swift package (`Sources/`). The app target in
`App/Sources` composes it into windows.

| Module | What it does |
|---|---|
| `CueCore` | Deck model, format adapters, parse5 source map, minimal source edits, show state |
| `CueRender` | WebKit surfaces, the isolated bridge, the `cue-deck:` scheme, the sandbox |
| `CueUI` | Shared design-system components: glass, glow, caret, controls |
| `CueEditor` | Editor state: selection, inspector, timeline, thumbnails, Claude's change sets |
| `CueImport` | PowerPoint, Keynote, OpenDocument and PDF import |
| `CueExport` | PowerPoint, PDF and PNG export |
| `CueMCP`, `cue-mcp` | The MCP server and the helper Claude starts |

[CONTRIBUTING.md](CONTRIBUTING.md) has the rules: one type per file, files under
300 lines, and `CueCore` free of UI frameworks. [docs/limits.md](docs/limits.md)
covers what Cue can't do, so it doesn't surprise anyone on stage.

## License

Cue is free software under the [GNU General Public License v3.0](LICENSE).
