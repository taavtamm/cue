import Foundation

/// Collects report notes from anywhere in a conversion.
final class ImportNotes {
    var report: ImportReport
    init(_ report: ImportReport) { self.report = report }
    func note(_ message: String, slide: Int? = nil) { report.note(message, slide: slide) }
}

/// Everything shape conversion needs while drawing one part (a slide, or
/// the layout or master behind it).
struct PptxContext {
    let package: PptxPackage
    /// The part whose relationships resolve `r:embed` ids.
    var part: String
    let theme: PptxTheme
    var colors: PptxColors
    let assets: AssetStore
    let notes: ImportNotes
    let fonts: FontCatalog
    /// 1-based, for report notes and slide-number fields.
    let slideNumber: Int
    let placeholders: PptxPlaceholders
    let defaultTextStyle: XNode?

    func note(_ message: String) { notes.note(message, slide: slideNumber) }

    /// The same context drawing another part (layout or master shapes).
    func drawing(_ other: String) -> PptxContext {
        var copy = self
        copy.part = other
        return copy
    }

    /// A picture referenced from this part, stored in the assets folder.
    func asset(relationship id: String?) -> String? {
        guard let id, let rel = package.relationships(of: part)[id] else { return nil }
        if rel.isExternal {
            note("A linked picture outside the file isn't included")
            return nil
        }
        let ext = (rel.target as NSString).pathExtension.lowercased()
        guard Self.webImageTypes.contains(ext) else {
            note("A picture in .\(ext) format can't be shown")
            return nil
        }
        guard let data = try? package.data(rel.target) else {
            note("A picture is missing from the file")
            return nil
        }
        return assets.add(data, key: rel.target, preferredName: (rel.target as NSString).lastPathComponent)
    }

    static let webImageTypes: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "svg", "webp", "tif", "tiff", "heic"]
}
