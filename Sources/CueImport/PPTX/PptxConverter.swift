import CueCore
import Foundation

/// PowerPoint (.pptx) → `ImportedDeck`, natively, on any Mac.
public struct PptxConverter: DeckImporter {
    public init() {}

    public func makeDeck(from url: URL, assets: AssetStore, report: inout ImportReport) async throws -> ImportedDeck {
        let zip: ZipArchive
        do { zip = try ZipArchive(contentsOf: url) } catch { throw ImportError.damaged(error.localizedDescription) }
        return try convert(zip, title: url.deletingPathExtension().lastPathComponent, assets: assets, report: &report)
    }

    func convert(_ zip: ZipArchive, title: String, assets: AssetStore, report: inout ImportReport) throws -> ImportedDeck {
        let package = PptxPackage(zip: zip)
        let info: PptxPresentationInfo
        do { info = try PptxPresentationInfo(package) } catch { throw ImportError.damaged(error.localizedDescription) }
        guard !info.slideParts.isEmpty else { throw ImportError.empty }

        let notes = ImportNotes(report)
        let fonts = FontCatalog()
        let slides = PptxSlideConverter(package: package, presentation: info, assets: assets, notes: notes, fonts: fonts)
        var deck = ImportedDeck(
            title: title,
            canvas: CanvasSize(width: (info.widthEMU / PptxUnits.emuPerPixel).rounded(),
                               height: (info.heightEMU / PptxUnits.emuPerPixel).rounded())
        )
        for (index, part) in info.slideParts.enumerated() {
            do {
                deck.slides.append(try slides.convert(part: part, number: index + 1))
            } catch {
                notes.note("This slide couldn't be read and is left blank", slide: index + 1)
                deck.slides.append(ImportedSlide(label: "Slide \(index + 1)"))
            }
        }
        for font in fonts.missing.sorted() {
            notes.note("The font “\(font)” isn't on this Mac; a similar font is used")
        }
        report = notes.report
        return deck
    }
}
