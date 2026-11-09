# Claude in Cue (MCP)

Cue runs an MCP server. Your own Claude Code or Claude Desktop connects to it
and edits the deck open in Cue. Cue never signs in to Claude: the work runs in
Anthropic's apps, on your plan.

```
Claude Code / Desktop ──stdio──▶ cue-mcp (inside Cue.app) ──Unix socket──▶ Cue (CueMCPServer)
```

## Set up

- **Claude Code:** run the command from Settings › Claude, e.g.
  `claude mcp add cue -- "/Applications/Cue.app/Contents/MacOS/cue-mcp"`.
- **Claude Desktop:** Settings › Claude › Add to Claude Desktop. It merges a
  `cue` entry into `~/Library/Application Support/Claude/claude_desktop_config.json`
  (backing the old file up as `claude_desktop_config.cue-backup-<time>.json`,
  never dropping other servers), then restart Claude Desktop.
- **First connection:** Cue shows "“claude-code” wants to edit decks in Cue"
  in its deck windows. Until you allow it, every tool answers "Waiting for
  approval in Cue". Answers are remembered per client (Settings › Claude ›
  Clients, with Revoke).

`cue-mcp` connects to `~/Library/Application Support/Cue/mcp.sock`. If Cue
isn't running it starts it in the background (`open -g`) and retries for 5 s,
then explains on stderr. `--socket <path>` or `CUE_MCP_SOCKET` override the
path (and never start the app). When Claude closes stdin the helper exits.

## Tools

Slide numbers are 1-based. Elements are targets: `{"cue_id": …}` or
`{"path": […]}` from `get_selection`, or `{"slide": 3, "selector": "h1.headline", "index": 0}`.

| Tool | What it does |
|---|---|
| create_deck | A new presentation (whole `html`, or Cue's blank deck), written as a new file inside the home folder, never over an existing one; opens and becomes the target |
| list_decks / open_deck | Decks open and recent; open one (presentation files only: HTML, PowerPoint, Keynote, OpenDocument, PDF) and make it the target |
| save_deck | Saves the target deck to its file (only when the user asks) |
| get_outline | File, canvas, every slide's number, id, label, notes, builds, live content |
| get_slide_html | One slide's HTML as written (large images as `CUE-IMAGE-…` placeholders) |
| get_selection | What the user selected: slide, tag, cue_id, path, start tag, computed styles |
| render_slide | PNG of a slide (final build unless `build`) |
| edit_element | Text, formatted html, attributes and/or inline style of one element |
| replace_slide_html | Replace a slide's whole element |
| add_slide / delete_slide / move_slide | Structure |
| set_notes / set_builds | Speaker notes, build order |
| insert_text_box / insert_image / insert_shape | New elements. Images: `url` (https, Cue downloads it), a data: URI or a file in the deck folder; embedded, ≤ 20 MB, scaled to ≤ 2× the canvas |
| move_element / resize_element / delete_element | Placement |
| list_changes / accept_change / revert_change | Change sets |
| next_request / complete_request | The Ask-bar loop |
| get_styles | The design system: theme variables, fonts, colours, top classes, stylesheets; with `selector`/`query`, matching rules |
| set_deck_style | Deck-wide CSS in Cue's `<style id="cue-overrides">` (merge by selector, or replace) |
| set_theme_variables | `:root` custom properties in the overrides |
| add_font | A Google Fonts `<link>` in `<head>` (shows once the user allows the two font hosts) |
| get_head / set_head_html | The `<head>` contents |
| get_deck_html / replace_deck_html | The whole document, for complete redesigns |
| get_embeds / edit_embed | A slide's live web embeds (sandboxed HTML) and its transition |
| set_transition | none, fade, push, magic (plays as fade) |
| render_deck | Contact sheet PNG of up to 24 slides |

Large images, stylesheets and scripts go to Claude as placeholders
(`data:image/png;base64,CUE-IMAGE-<hash>`, `/* CUE-BLOCK-<hash>: … */`) and are
restored from the deck in any HTML Claude sends back, so a rewritten slide,
head or document keeps them. An unknown placeholder is refused.

## Redesigns

The server's instructions give Claude this workflow:

1. `get_outline`, then `get_styles` for the design system and `render_deck` to see every slide.
2. Deck-wide looks: `set_theme_variables` (decks built on variables) or `set_deck_style`
   (any CSS, `!important` where the deck styles inline). `add_font` for type.
3. One element: `edit_element`. A new layout: `replace_slide_html`. Pictures:
   `insert_image` with a `url`. Everything at once: `replace_deck_html`.
4. Check with `render_deck` or `render_slide`.

The deck's own stylesheets are never rewritten: deck-wide styles live in Cue's
override block, loaded after them, so removing that block undoes every style
change. Claude Design decks keep transitions and embeds in their deck-motion
JSON, which is patched in place; Cue-convention decks use
`data-cue-transition` on the slide (the generic player plays fade and push).
Other formats: embeds are `<iframe srcdoc>` on the slide (`iframe-1`, …);
transitions are written as `data-cue-transition` but only Cue's players play them.

Resources: `cue://deck/outline`, `cue://deck/slide/{n}/html`,
`cue://editor/selection`, `cue://deck/assets`.

## Change sets

Every tool call that changes the deck is one change: applied and kept
immediately (the slide shows it, it's in Edit › Undo), not saved to the file
until the user saves, and it returns a change-set id. The user, or Claude with
`revert_change`, can undo it. `accept_change` only matters when the user has
turned on "Review Claude's edits before keeping them" in Settings › Claude.

Each change set can be undone on its own later: `ChangeSetLedger` keeps its
inverse patch and shifts it past every later edit. If a later edit touched the
same text, the change set becomes *superseded* and Cue refuses to undo it on
its own (Edit › Undo still works). A tool call that runs several edits is one
change set; in the undo history it may be several steps.

## The Ask bar

The bar under the slide is the agent's status line: "Agent not connected",
"Claude Code connected · ready", "Reading slide 3…", "Editing slide 3 · …",
then what changed, with Undo. The user talks to their agent in its own app.

Cue's queue of typed requests is still served for clients that want it:
`next_request` waits for a request and `complete_request` reports back. If an
approved client declares MCP **sampling**, Cue can also serve a request itself
through `sampling/createMessage`, asking for one JSON plan of edit-tool calls.
The SDK (0.12.1) can't pass tool definitions with sampling, hence the single
structured reply.

## Security

- Local only: a Unix socket in a 0700 folder, the socket itself 0600, so other
  macOS accounts can't connect. No network port.
- Every client is approved by the user once; denied clients get a clear error.
  This is a consent prompt for processes running as the same user, not
  authentication: approval is keyed on the name the client sends in
  `initialize`, which any local process could claim. Calls before
  `initialize` are refused.
- Edits never save by themselves; each is one change the user (or Claude) can
  undo. Only `save_deck`, which Claude is told to use when the user asks,
  writes the target deck to its file, and `create_deck` writes new files only.
- `open_deck` opens presentation files only (by extension, after resolving
  symlinks), so Claude can't read or rewrite other files by opening them as a deck.
- Claude can't reach the network through the deck: `add_font` only writes the
  `<link>`, and the deck's sandbox still asks the user to allow the font hosts.
  `insert_image` with a `url` is Cue downloading on Claude's request (https only,
  20 MB, must be an image); the change's summary names the host.
- Images Claude inserts by path must be inside the deck's folder.
- The helper never writes to stdout except MCP bytes from Cue.

## Manual checks (need the screen)

1. Launch Cue, open fixtures/demo-deck.html (a copy). Settings › Claude shows "Ready".
2. `claude mcp add cue -- "<Cue.app>/Contents/MacOS/cue-mcp"`, start `claude`, ask it to call get_outline.
   Cue shows the approval banner; Allow; the call succeeds.
3. In Claude Code, "make slide 3's headline shorter". Within about a second the slide changes and the
   Ask bar shows what changed. Undo restores the headline.
4. Ask Claude to "make a three-slide deck about tide pools": create_deck opens a new window with it, and
   the Ask bar animates while Claude edits.
5. render_slide returns a picture of the slide (Claude can describe it).
6. Settings › Claude › Add to Claude Desktop, restart Claude Desktop, repeat step 3 there.
7. Quit Cue while Claude is connected: the helper keeps running and answers "Cue isn't running";
   reopen Cue and the next call works without reconnecting.
