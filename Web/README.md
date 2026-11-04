# Web

Build scripts for the JavaScript Cue ships inside the app.

`src/parse.js` wraps [parse5](https://parse5.js.org) and exposes
`globalThis.cueParse(html)`, which returns a JSON element tree with source
offsets. CueCore runs it in a bare JavaScriptCore context (see
`Sources/CueCore/Parsing/HTMLParser.swift`).

```sh
npm install
npm run build   # writes Sources/CueCore/Resources/parse5.bundle.js
```

The built bundle is checked in, so building the app never needs Node.
Rebuild it after changing `src/` or bumping parse5.
