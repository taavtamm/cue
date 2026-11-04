import Foundation

/// An Open XML package: parts by path, each with its relationships file.
/// Paths are absolute within the archive, without a leading slash
/// (`ppt/slides/slide1.xml`).
final class PptxPackage {
    struct Relationship {
        let id: String
        /// The last component of the type URI: `image`, `slideLayout`, `notesSlide`…
        let type: String
        /// Resolved archive path, or the raw URL for external targets.
        let target: String
        let isExternal: Bool
    }

    let zip: ZipArchive
    private var xmlCache: [String: XNode] = [:]
    private var relsCache: [String: [String: Relationship]] = [:]

    init(zip: ZipArchive) {
        self.zip = zip
    }

    func xml(_ path: String) throws -> XNode {
        if let cached = xmlCache[path] { return cached }
        let node = try XMLTreeParser.parse(try zip.data(for: path), name: path)
        xmlCache[path] = node
        return node
    }

    func data(_ path: String) throws -> Data { try zip.data(for: path) }

    func contains(_ path: String) -> Bool { zip.contains(path) }

    /// Relationships of `part`, keyed by id. Missing rels files mean none.
    func relationships(of part: String) -> [String: Relationship] {
        if let cached = relsCache[part] { return cached }
        let folder = (part as NSString).deletingLastPathComponent
        let relsPath = (folder.isEmpty ? "" : folder + "/") + "_rels/" + (part as NSString).lastPathComponent + ".rels"
        var result: [String: Relationship] = [:]
        if let root = try? xml(relsPath) {
            for rel in root.children("Relationship") {
                guard let id = rel["Id"], let target = rel["Target"], let type = rel["Type"] else { continue }
                let external = rel["TargetMode"] == "External"
                result[id] = Relationship(
                    id: id,
                    type: (type as NSString).lastPathComponent,
                    target: external ? target : Self.resolve(target, from: part),
                    isExternal: external
                )
            }
        }
        relsCache[part] = result
        return result
    }

    /// The first relationship of `type` from `part`, e.g. a slide's layout.
    func related(_ part: String, type: String) -> String? {
        relationships(of: part).values.filter { $0.type == type && !$0.isExternal }.map(\.target).sorted().first
    }

    /// Resolves a relative target against the part's folder, handling `..`.
    static func resolve(_ target: String, from part: String) -> String {
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        var components = (part as NSString).deletingLastPathComponent.split(separator: "/").map(String.init)
        for piece in target.split(separator: "/").map(String.init) {
            switch piece {
            case ".": continue
            case "..": if !components.isEmpty { components.removeLast() }
            default: components.append(piece)
            }
        }
        return components.joined(separator: "/")
    }
}
