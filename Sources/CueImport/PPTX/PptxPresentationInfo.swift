import Foundation

/// `ppt/presentation.xml`: slide order, slide size and the default text style.
struct PptxPresentationInfo {
    let slideParts: [String]
    let widthEMU: Double
    let heightEMU: Double
    let defaultTextStyle: XNode?

    init(_ package: PptxPackage) throws {
        let mainPart = Self.mainPart(package)
        let root = try package.xml(mainPart)
        let rels = package.relationships(of: mainPart)
        slideParts = (root.child("sldIdLst")?.children("sldId") ?? []).compactMap { rels[$0["r:id"] ?? ""]?.target }
            .filter(package.contains)
        widthEMU = root.child("sldSz")?.double("cx") ?? 12_192_000
        heightEMU = root.child("sldSz")?.double("cy") ?? 6_858_000
        defaultTextStyle = root.child("defaultTextStyle")
    }

    /// The package's officeDocument relationship, usually `ppt/presentation.xml`.
    private static func mainPart(_ package: PptxPackage) -> String {
        package.relationships(of: "").values.first { $0.type == "officeDocument" }?.target ?? "ppt/presentation.xml"
    }
}
