import CoreGraphics
import CueCore
import Foundation

/// Editor queries on a surface: inspecting an element, the slide's
/// animations, live embeds and inline text editing. Coordinates in and out
/// are the surface's (AppKit, origin bottom-left).
extension SlideRenderer {
    /// How an element looks and where it sits. `buildTargets` are the slide's
    /// build steps as selectors, so the result can say which step reveals it.
    public func inspect(
        cueID: String, slideSelector: String, canvasWidth: Double, buildTargets: [[String]] = []
    ) async throws -> ElementInspection? {
        let value = try await callInBridge(
            "return window.__cue.inspect.element(id, selector, width, steps)",
            arguments: ["id": cueID, "selector": slideSelector, "width": canvasWidth, "steps": buildTargets]
        )
        guard let info = value as? [String: Any], let rect = info["rect"] as? [String: Any],
              let canvas = info["canvas"] as? [String: Any] else { return nil }
        return ElementInspection(
            frame: viewRect(fromCSS: Self.rect(rect)),
            canvasFrame: Self.rect(canvas),
            computedStyle: info["style"] as? [String: String] ?? [:],
            buildStep: info["build"] as? Int,
            isLeaf: info["isLeaf"] as? Bool ?? false,
            hostsEmbed: info["hostsEmbed"] as? Bool ?? false
        )
    }

    public func animations(onSlide index: Int, slideSelector: String) async throws -> SlideAnimations {
        let value = try await callInBridge(
            "return window.__cue.inspect.animations(selector, index)",
            arguments: ["selector": slideSelector, "index": index]
        )
        let info = value as? [String: Any] ?? [:]
        let tracks = (info["tracks"] as? [[String: Any]] ?? []).map { track in
            SlideAnimations.Track(
                name: track["name"] as? String ?? "animation", target: track["target"] as? String ?? "",
                delay: (track["delay"] as? Double ?? 0) / 1000, duration: (track["duration"] as? Double ?? 0) / 1000,
                iterations: track["iterations"] as? Double ?? 1, easing: track["easing"] as? String ?? "linear"
            )
        }
        return SlideAnimations(tracks: tracks, embedCount: info["embeds"] as? Int ?? 0)
    }

    /// What keeps the GPU busy on the slide (takes about a second: redraws are counted over it).
    public func load(onSlide index: Int, slideSelector: String) async throws -> SlideLoad? {
        let value = try await callInBridge(
            "return await window.__cue.inspect.load(selector, index)",
            arguments: ["selector": slideSelector, "index": index]
        )
        guard let info = value as? [String: Any] else { return nil }
        return SlideLoad(blurs: info["blurs"] as? Int ?? 0, loopingAnimations: info["loops"] as? Int ?? 0,
                         embeds: info["embeds"] as? Int ?? 0, redrawsPerSecond: info["redraws"] as? Int ?? 0)
    }

    public func replayAnimations(onSlide index: Int, slideSelector: String) async throws {
        _ = try await callInBridge(
            "window.__cue.inspect.replay(selector, index)", arguments: ["selector": slideSelector, "index": index]
        )
    }

    /// The live embed under a point, if any.
    public func liveEmbed(at point: CGPoint) async throws -> CGRect? {
        let css = CGPoint(x: point.x, y: bounds.height - point.y)
        let value = try await callInBridge(
            "return window.__cue.inspect.embedAt(x, y)", arguments: ["x": css.x, "y": css.y]
        )
        return (value as? [String: Any]).map { viewRect(fromCSS: Self.rect($0)) }
    }

    /// Lets live embeds take clicks, or makes them inert again.
    public func setEmbedsInteractive(_ interactive: Bool) async throws {
        _ = try await callInBridge(
            "window.__cue.inspect.setEmbedsInteractive(on)", arguments: ["on": interactive]
        )
    }

    /// Starts editing a leaf element's text on the slide. Progress arrives as
    /// `.textEditing` events. Returns false for elements with children.
    public func beginTextEditing(cueID: String) async throws -> Bool {
        try await callInBridge("return window.__cue.inlineText.begin(id)", arguments: ["id": cueID]) as? Bool ?? false
    }

    /// Ends inline editing: commit sends the text, cancel restores the original.
    /// Formats the text being edited: "bold", "italic", "underline",
    /// "createLink" (with a URL), "insertLineBreak", "removeFormat".
    public func formatText(_ command: String, value: String? = nil) async throws {
        _ = try await callInBridge("window.__cue.inlineText.format(command, value)",
                                   arguments: ["command": command, "value": value ?? NSNull()])
    }

    public func endTextEditing(commit: Bool) async throws {
        _ = try await callInBridge("window.__cue.inlineText.finish(commit)", arguments: ["commit": commit])
    }

    /// A rect in the page's CSS pixels (origin top-left) in this view's coordinates.
    public func viewRect(fromCSS rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: bounds.height - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func rect(_ values: [String: Any]) -> CGRect {
        CGRect(
            x: values["x"] as? Double ?? 0, y: values["y"] as? Double ?? 0,
            width: values["width"] as? Double ?? 0, height: values["height"] as? Double ?? 0
        )
    }
}
