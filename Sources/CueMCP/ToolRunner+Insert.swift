import CueCore
import Foundation

/// Text boxes, images and shapes from Claude: the same markup the editor's
/// Insert menu makes (`ElementTemplate`), placed where Claude asks.
extension ToolRunner {
    /// Largest image Claude may embed, so a deck stays a sensible size.
    static let maximumImageBytes = 8 * 1024 * 1024

    func insertion(_ name: String, _ args: ToolArguments, _ document: DeckDocument) throws -> String {
        let template: ElementTemplate
        switch name {
        case "insert_text_box":
            template = .textBox(text: try args.requiredString("text"), fontSize: args.int("font_size") ?? 48,
                                fontFamily: args.string("font_family"))
        case "insert_image":
            let source = try imageSource(try args.requiredString("source"), deckFolder: document.fileURL.deletingLastPathComponent())
            template = .image(source: source, description: try args.requiredString("description"))
        default:
            guard let shape = args.string("shape").flatMap(ElementTemplate.Shape.init(rawValue:)) else {
                throw CueMCPError.invalid("“shape” must be rectangle, roundedRectangle, ellipse, line or arrow.")
            }
            template = .shape(shape)
        }
        let canvas = document.structure.canvas
        var frame = template.defaultFrame(on: CGSize(width: canvas.width, height: canvas.height))
        if let x = args.double("x") { frame.origin.x = x }
        if let y = args.double("y") { frame.origin.y = y }
        if let width = args.double("width"), width > 0 { frame.size.width = width }
        if let height = args.double("height"), height > 0 { frame.size.height = height }
        let prefix = name == "insert_text_box" ? "text" : name == "insert_image" ? "image" : "shape"
        return template.html(id: ElementTemplate.uniqueID(prefix: "cue-\(prefix)", in: document.source), frame: frame)
    }

    /// A `data:` URI as given, or a file inside the deck's folder read and
    /// embedded. Files outside the folder are refused, like everything else
    /// a deck might reach for.
    func imageSource(_ source: String, deckFolder: URL) throws -> String {
        if source.hasPrefix("data:image/") { return source }
        let folder = deckFolder.standardizedFileURL.resolvingSymlinksInPath()
        let file = URL(filePath: source, relativeTo: folder).standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(folder.path + "/") else {
            throw CueMCPError.invalid("Images must be a data: URI or a file inside the deck's folder (\(folder.path)).")
        }
        let type: String
        switch file.pathExtension.lowercased() {
        case "png": type = "image/png"
        case "jpg", "jpeg": type = "image/jpeg"
        case "gif": type = "image/gif"
        case "webp": type = "image/webp"
        case "svg": type = "image/svg+xml"
        default: throw CueMCPError.invalid("Cue embeds PNG, JPEG, GIF, WebP or SVG images, not “\(file.pathExtension)”.")
        }
        let data: Data
        do { data = try Data(contentsOf: file) } catch {
            throw CueMCPError.invalid("Couldn't read \(file.lastPathComponent): \(error.localizedDescription)")
        }
        guard data.count <= Self.maximumImageBytes else {
            throw CueMCPError.invalid("\(file.lastPathComponent) is \(data.count / 1_048_576) MB; Cue embeds images up to 8 MB.")
        }
        return "data:\(type);base64,\(data.base64EncodedString())"
    }
}
