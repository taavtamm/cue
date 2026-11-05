import MCP

/// Cue's tools, as Claude sees them. Slide numbers are 1-based. Every tool
/// that changes the deck is one change: applied and kept at once (not saved
/// until the user saves), with a change-set id that `revert_change` undoes.
enum ToolCatalog {
    static let tools: [Tool] = reading + slides + elements + inserting + DesignTools.tools + changes + asking

    static let reading: [Tool] = [
        tool("get_outline", "The open deck: file, canvas size, and every slide's number, id, label, notes, build count "
             + "and whether it has live web content. Start here.", [:], readOnly: true),
        tool("get_slide_html", "One slide's HTML as written in the file, except that large embedded images "
             + "(base64 data: URIs) appear as placeholders like data:image/png;base64,CUE-IMAGE-3f2a9c1d07b4e6a8. "
             + "Keep placeholders exactly as they are in HTML you send back; Cue puts the images back.",
             ["slide": slideNumber], ["slide"],
             readOnly: true),
        tool("get_selection", "What the user is looking at and has selected in Cue right now: slide, element tag, "
             + "cue_id and path (usable as a target), its start tag in the file, and its computed styles.", [:],
             readOnly: true),
        tool("render_slide", "A PNG of a slide as Cue renders it, to check your work. Shows the final build unless "
             + "“build” is given.", ["slide": slideNumber, "build": integer("Build step, 0 = before any build.")],
             ["slide"], readOnly: true),
    ]

    static let slides: [Tool] = [
        tool("replace_slide_html", "Replaces one slide's whole markup. Keep the same outer element (e.g. the "
             + "<section> with its class and data attributes) so it stays a slide.",
             ["slide": slideNumber, "html": string("The new slide element."), "summary": summary], ["slide", "html"]),
        tool("add_slide", "Adds a slide after slide “after” (0 = at the start). With no html, an empty slide in "
             + "the deck's own structure.", ["after": integer("1-based slide to add after, 0 for the start."),
                                            "html": string("Optional markup for the new slide."), "summary": summary],
             ["after"]),
        tool("delete_slide", "Deletes a slide.", ["slide": slideNumber, "summary": summary], ["slide"], destructive: true),
        tool("move_slide", "Moves a slide so it ends up at position “to”.",
             ["slide": slideNumber, "to": integer("1-based position it should end up at."), "summary": summary],
             ["slide", "to"]),
        tool("set_notes", "Sets a slide's speaker notes (plain text).",
             ["slide": slideNumber, "text": string("The notes."), "summary": summary], ["slide", "text"]),
        tool("set_builds", "Sets a slide's build order: each step reveals its targets on the next click.",
             ["slide": slideNumber, "summary": summary,
              "steps": ["type": "array", "items": object([
                  "targets": ["type": "array", "items": target, "description": "Elements this step reveals."],
                  "effect": string("Optional: fade, rise, drop, left, right, scale, pop."),
              ], required: ["targets"])]], ["slide", "steps"]),
    ]

    static let elements: [Tool] = [
        tool("edit_element", "Changes one element: its text (plain), its formatted html (b, i, u, a, br, span), "
             + "attributes, and/or inline style. Values of null remove an attribute or style property.",
             ["target": target, "text": string("New plain text (element with no child elements)."),
              "html": string("New inner HTML with simple formatting."),
              "attributes": ["type": "object", "description": "Attribute → value, or null to remove."],
              "style": ["type": "object", "description": "CSS property → value, or null to remove."],
              "summary": summary], ["target"]),
        tool("move_element", "Moves an element by dx, dy design-canvas pixels (the slide's own size, e.g. 1920×1080).",
             ["target": target, "dx": number("Pixels right."), "dy": number("Pixels down."), "summary": summary],
             ["target", "dx", "dy"]),
        tool("resize_element", "Sets an element's width and height in design-canvas pixels.",
             ["target": target, "width": number("Pixels."), "height": number("Pixels."), "summary": summary],
             ["target", "width", "height"]),
        tool("delete_element", "Deletes an element.", ["target": target, "summary": summary], ["target"],
             destructive: true),
    ]

    static let inserting: [Tool] = [
        tool("insert_text_box", "Adds a text box to a slide.",
             frame.merging(["slide": slideNumber, "text": string("The text."), "font_size": number("Pixels."),
                            "font_family": string("Optional font family."), "summary": summary]) { a, _ in a },
             ["slide", "text"]),
        tool("insert_image", "Adds an image to a slide, embedded in the HTML (the deck stays one file). Give "
             + "“url” (https; Cue downloads it) or “source” (a data: URI or a file path inside the deck's folder). "
             + "Images larger than twice the slide are scaled down. To replace an existing image, use "
             + "edit_element on it with a new src attribute instead.",
             frame.merging(["slide": slideNumber, "url": string("https:// address of the image."),
                            "source": string("data: URI or file path in the deck folder."),
                            "description": string("Alt text."), "summary": summary]) { a, _ in a },
             ["slide", "description"]),
        tool("insert_shape", "Adds a shape to a slide.",
             frame.merging(["slide": slideNumber, "summary": summary,
                            "shape": ["type": "string", "enum": ["rectangle", "roundedRectangle", "ellipse", "line", "arrow"]]]) { a, _ in a },
             ["slide", "shape"]),
    ]

    static let changes: [Tool] = [
        tool("list_changes", "Change sets made in this session and their status (accepted = kept, pending = waiting "
             + "for the user's review, reverted, superseded).", [:], readOnly: true),
        tool("accept_change", "Keeps a pending change set. Only needed when the user turned on reviewing.",
             ["id": string("Change-set id.")], ["id"]),
        tool("revert_change", "Undoes one change set, restoring exactly what was there.", ["id": string("Change-set id.")], ["id"]),
    ]

    static let asking: [Tool] = [
        tool("next_request", "Waits for the next request the user types into Cue's Ask bar and returns it (text, "
             + "slide, selection). Returns null after the timeout; call it again. Do what each request asks with "
             + "Cue's tools, then call complete_request.",
             ["timeout_seconds": integer("How long to wait, 1–300. Default 50.")], readOnly: true),
        tool("complete_request", "Marks an Ask-bar request as done, with a one-line summary the user sees.",
             ["id": string("Request id from next_request."), "summary": string("What you changed.")], ["id", "summary"]),
    ]

    // MARK: Schema helpers

    static let slideNumber: Value = integer("1-based slide number.")
    static let summary: Value = string("One short line for the user describing the change.")
    static let target: Value = object([
        "cue_id": string("Live id from get_selection."),
        "path": ["type": "array", "items": ["type": "integer"], "description": "Element path from get_selection."],
        "slide": integer("1-based slide, for a selector."),
        "selector": string("CSS selector within the slide: tag, #id, .class, [attr], descendants."),
        "index": integer("0-based, when the selector matches several."),
    ], description: "The element: cue_id, path, or slide + selector.")
    static let frame: [String: Value] = [
        "x": number("Left, in design-canvas pixels."), "y": number("Top, in design-canvas pixels."),
        "width": number("Pixels."), "height": number("Pixels."),
    ]

    static func string(_ description: String) -> Value { ["type": "string", "description": .string(description)] }
    static func integer(_ description: String) -> Value { ["type": "integer", "description": .string(description)] }
    static func number(_ description: String) -> Value { ["type": "number", "description": .string(description)] }

    static func object(_ properties: [String: Value], required: [String] = [], description: String? = nil) -> Value {
        var schema: [String: Value] = ["type": "object", "properties": .object(properties)]
        if !required.isEmpty { schema["required"] = .array(required.map { .string($0) }) }
        if let description { schema["description"] = .string(description) }
        return .object(schema)
    }

    static func tool(_ name: String, _ description: String, _ properties: [String: Value], _ required: [String] = [],
                     readOnly: Bool = false, destructive: Bool = false) -> Tool {
        Tool(name: name, description: description, inputSchema: object(properties, required: required),
             annotations: .init(readOnlyHint: readOnly, destructiveHint: destructive, openWorldHint: false))
    }
}
