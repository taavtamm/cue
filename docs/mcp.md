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
| get_outline | File, canvas, every slide's number, id, label, notes, builds, live content |
| get_slide_html | One slide's HTML as written |
| get_selection | What the user selected: slide, tag, cue_id, path, start tag, computed styles |
| render_slide | PNG of a slide (final build unless `build`) |
| edit_element | Text, formatted html, attributes and/or inline style of one element |
| replace_slide_html | Replace a slide's whole element |
| add_slide / delete_slide / move_slide | Structure |
| set_notes / set_builds | Speaker notes, build order |
| insert_text_box / insert_image / insert_shape | New elements (images: data: URI or a file in the deck folder, embedded, ≤ 8 MB) |
| move_element / resize_element / delete_element | Placement |
| list_changes / accept_change / revert_change | Change sets |
| next_request / complete_request | The Ask-bar loop |

Resources: `cue://deck/outline`, `cue://deck/slide/{n}/html`,
`cue://editor/selection`, `cue://deck/assets`.

## Change sets

Every write applies at once (the slide shows it, it's in Edit › Undo) and
returns a change-set id. Nothing is saved. A banner on the canvas shows the
latest pending change with a before/after and **Accept** / **Undo**; "All
changes" lists them. Settings › Claude › Auto-accept skips the waiting.

Each change set can be undone on its own later: `ChangeSetLedger` keeps its
inverse patch and shifts it past every later edit. If a later edit touched the
same text, the change set becomes *superseded* and Cue refuses to undo it on
its own (Edit › Undo still works). A tool call that runs several edits is one
change set; in the undo history it may be several steps.

## The Ask bar

Typing in Cue's Ask bar posts a request. A Claude Code session that runs the
instruction from Settings › Claude ("call next_request in a loop…") takes it,
does the work with the tools above, and calls `complete_request`; the bar shows
Waiting for Claude… → Claude is working… → Claude's summary.

If the connected client declares MCP **sampling**, Cue serves the request
itself: it sends the request, outline, selection and slide HTML through
`sampling/createMessage` and asks for one JSON plan of tool calls, which it
runs (edit tools only). The SDK (0.12.1) can't pass tool definitions with
sampling, hence the single structured reply. Claude's apps don't seem to offer
sampling yet, so in practice the `next_request` loop is the path.

## Security

- Local only: a Unix socket in a 0700 folder, the socket itself 0600, so other
  macOS accounts can't connect. No network port.
- Every client is approved by the user once; denied clients get a clear error.
- Writes never save; the user accepts or undoes each change.
- Images Claude inserts by path must be inside the deck's folder.
- The helper never writes to stdout except MCP bytes from Cue.

## Manual checks (need the screen)

1. Launch Cue, open fixtures/demo-deck.html (a copy). Settings › Claude shows "Ready".
2. `claude mcp add cue -- "<Cue.app>/Contents/MacOS/cue-mcp"`, start `claude`, ask it to call get_outline.
   Cue shows the approval banner; Allow; the call succeeds.
3. The brief's test: in Claude Code, "make slide 3's headline shorter". Within about a second the slide
   changes and the change banner appears with before/after. Undo restores the headline; Accept keeps it.
4. Paste the Ask-bar instruction into Claude Code, then type a request in Cue's Ask bar: the bar shows
   Waiting → Working → Claude's summary, and the change banner appears.
5. render_slide returns a picture of the slide (Claude can describe it).
6. Settings › Claude › Add to Claude Desktop, restart Claude Desktop, repeat step 3 there.
7. Quit Cue while Claude is connected: the helper exits; reopen and reconnect.
