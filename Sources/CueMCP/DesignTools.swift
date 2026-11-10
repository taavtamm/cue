import MCP

/// The deck-wide tools for redesigns, as Claude sees them.
enum DesignTools {
    typealias Catalog = ToolCatalog

    static let tools: [Tool] = [
        Catalog.tool("get_styles", "The deck's design system: theme variables (custom properties), font families, "
            + "colours in use, the most used classes and what they style, linked stylesheets, @font-face fonts, and "
            + "Cue's override stylesheet. With “selector” or “query”, the CSS rules that mention it, from every "
            + "stylesheet. Summarised: stylesheets can be hundreds of KB.",
            ["selector": Catalog.string("Rules whose selector contains this, e.g. .headline or h1."),
             "query": Catalog.string("Rules whose text contains this, e.g. #141414 or font-size.")], readOnly: true),
        Catalog.tool("set_deck_style", "Writes deck-wide CSS into Cue's own override stylesheet (<style "
            + "id=\"cue-overrides\">, loaded after the deck's CSS). The deck's own stylesheets are never rewritten. "
            + "“merge” (default) adds rules and replaces rules with the same selector; “replace” replaces the whole "
            + "override stylesheet. Use !important when the deck sets the property inline.",
            ["css": Catalog.string("CSS rules, @media and @keyframes included."),
             "mode": ["type": "string", "enum": ["merge", "replace"]], "summary": Catalog.summary], ["css"]),
        Catalog.tool("set_theme_variables", "Sets CSS custom properties on :root in Cue's override stylesheet, e.g. "
            + "{\"--accent\": \"#2f7bff\"}. The quickest way to recolour a deck built on variables (see get_styles). "
            + "null removes one.",
            ["variables": ["type": "object", "description": "Custom property → value, or null to remove."],
             "summary": Catalog.summary], ["variables"]),
        Catalog.tool("add_font", "Adds a Google Fonts family to the deck's <head>. Then use it with set_deck_style "
            + "or edit_element. Cue blocks the network until the user allows fonts.googleapis.com and "
            + "fonts.gstatic.com for this deck (Cue asks them), so the font shows once they allow it.",
            ["family": Catalog.string("e.g. Inter, Playfair Display."),
             "weights": ["type": "array", "items": ["type": "integer"], "description": "e.g. [400, 700]."],
             "summary": Catalog.summary], ["family"]),
        Catalog.tool("get_head", "The deck's <head> contents (meta, title, links, styles, scripts). Large blocks "
            + "and images come as CUE-BLOCK / CUE-IMAGE placeholders: keep them exactly as they are.", [:], readOnly: true),
        Catalog.tool("set_head_html", "Replaces the deck's <head> contents. Keep placeholders as get_head gave them "
            + "and Cue restores them.", ["html": Catalog.string("The new head contents."), "summary": Catalog.summary],
            ["html"]),
        Catalog.tool("get_deck_html", "The whole document, with large images, stylesheets and scripts as "
            + "placeholders. For a complete redesign; for one slide use get_slide_html.", [:], readOnly: true),
        Catalog.tool("replace_deck_html", "Replaces the whole document: a complete redesign in one change. Keep "
            + "placeholders exactly as get_deck_html gave them. The result must still have slides Cue can find: keep "
            + "the deck's slide elements (e.g. section.deck-slide) or use <section data-cue-slide> for each slide.",
            ["html": Catalog.string("The new document."), "summary": Catalog.summary], ["html"], destructive: true),
        Catalog.tool("get_embeds", "A slide's live web embeds (their own HTML, run sandboxed) and its transition.",
            ["slide": Catalog.slideNumber], ["slide"], readOnly: true),
        Catalog.tool("edit_embed", "Replaces one live web embed's HTML. It keeps running sandboxed, without network.",
            ["slide": Catalog.slideNumber, "embed": Catalog.string("Embed id from get_embeds."),
             "html": Catalog.string("The embed's new HTML document."), "summary": Catalog.summary],
            ["slide", "embed", "html"]),
        Catalog.tool("set_transition", "How the deck moves on from a slide: none, fade, push or magic (magic plays "
            + "as a fade for now).",
            ["slide": Catalog.slideNumber, "kind": ["type": "string", "enum": ["none", "fade", "push", "magic"]],
             "summary": Catalog.summary], ["slide", "kind"]),
        Catalog.tool("render_deck", "A contact sheet PNG of slides as Cue renders them (finished builds), numbered, "
            + "to review a redesign at a glance. Up to 24 slides.",
            ["slides": ["type": "array", "items": ["type": "integer"], "description": "1-based slides; default all."],
             "columns": Catalog.integer("Columns, default by count.")], readOnly: true),
        Catalog.tool("get_performance", "What keeps the GPU busy on each slide while it plays: visible "
            + "backdrop-filter blurs, animations that never end, live embeds/video/canvas, and the deck's own "
            + "requestAnimationFrame calls per second, with Cue's verdict and reasons. Slides the user has shown "
            + "in the editor are measured live; the rest off screen, where embeds don't start and redraws can't be "
            + "counted (measured_live false). "
            + "Takes about two seconds per slide. Use it before and after making a deck lighter.",
            ["slides": ["type": "array", "items": ["type": "integer"], "description": "1-based slides; default all."]],
            readOnly: true),
    ]
}
