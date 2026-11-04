import Foundation

/// The deck File › New writes: plain HTML in Cue's own convention, so any
/// browser can still open it. One title slide at 1920 × 1080 with a title
/// and a subtitle, speaker notes in `data-cue-notes`, a small embedded
/// stylesheet, no scripts and no network.
public enum BlankDeckTemplate {
    /// Used when the chosen font is "System".
    public static let systemFontStack =
        #"-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", Arial, sans-serif"#

    public static func html(
        title: String = "Untitled Presentation",
        fontFamily: String = CueSettings.systemFont,
        subtitleSize: Double = 48,
        canvas: CanvasSize = .hd
    ) -> String {
        let escape = HTMLEscaping(encoding: .utf8)
        let width = Int(canvas.width), height = Int(canvas.height)
        return """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="cue:canvas" content="\(width)x\(height)">
            <meta name="generator" content="Cue">
            <title>\(escape.text(title))</title>
            <style>
            \(stylesheet(fontFamily: fontFamily, subtitleSize: subtitleSize, width: width, height: height))
            </style>
            </head>
            <body>
            <section id="slide-1" data-cue-slide data-cue-notes="">
              <h1 class="cue-title">\(escape.text(title))</h1>
              <p class="cue-subtitle">Subtitle</p>
            </section>
            </body>
            </html>

            """
    }

    /// The deck's only stylesheet: readable defaults, the system font stack.
    static func stylesheet(fontFamily: String, subtitleSize: Double, width: Int, height: Int) -> String {
        """
            :root {
              --cue-font: \(fontStack(fontFamily));
              --cue-ink: #141414; --cue-muted: #5f5e5a; --cue-paper: #f7f6f2;
            }
            html, body { margin: 0; background: #000; }
            [data-cue-slide] {
              position: relative; box-sizing: border-box; overflow: hidden;
              width: \(width)px; height: \(height)px;
              background: var(--cue-paper); color: var(--cue-ink); font-family: var(--cue-font);
            }
            [data-cue-slide] + [data-cue-slide] { margin-top: 40px; }
            .cue-title {
              position: absolute; left: 160px; top: 360px; width: \(width - 320)px; margin: 0;
              font-size: 120px; font-weight: 700; line-height: 1.05; letter-spacing: -0.02em;
            }
            .cue-subtitle {
              position: absolute; left: 160px; top: 540px; width: \(width - 320)px; margin: 0;
              font-size: \(format(subtitleSize))px; font-weight: 400; line-height: 1.3; color: var(--cue-muted);
            }
            """
    }

    /// A CSS font-family value. Names are reduced to letters, digits,
    /// spaces and hyphens, so a font name can never break out of the rule.
    static func fontStack(_ family: String) -> String {
        let name = String(family.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " " || $0 == "-"
        }).trimmingCharacters(in: .whitespaces)
        if name.isEmpty || name == CueSettings.systemFont { return systemFontStack }
        return "\"\(name)\", \(systemFontStack)"
    }

    private static func format(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
