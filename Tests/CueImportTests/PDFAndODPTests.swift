// swiftlint:disable line_length
// Office XML fixtures read best as one element per line.

import CueCore
import Foundation
import Testing
@testable import CueImport

@Suite("PDF and OpenDocument import")
struct PDFAndODPTests {
    @Test func pdfPagesBecomePictureSlides() async throws {
        let folder = TempFolder()
        let pdf = folder.url.appendingPathComponent("Handout.pdf")
        TestImages.pdf(pages: [CGSize(width: 720, height: 405), CGSize(width: 720, height: 405), CGSize(width: 612, height: 792)],
                       to: pdf)
        let prepared = try await ImportService().prepare(pdf)
        let report = try #require(prepared.report)
        #expect(report.isPresentOnly)

        let document = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(document.structure.slides.count == 3)
        #expect(document.structure.canvas == CanvasSize(width: 960, height: 540))
        let assets = prepared.htmlURL.deletingLastPathComponent().appendingPathComponent("Handout (Cue) assets")
        let page = try Data(contentsOf: assets.appendingPathComponent("page-1.png"))
        #expect(ImageSize.of(page) == CGSize(width: 1920, height: 1080), "pages render at 2×")
    }

    @Test func odpWithoutKeynoteKeepsTextPicturesAndNotes() async throws {
        let folder = TempFolder()
        var zip = ZipWriter()
        zip.add("mimetype", "application/vnd.oasis.opendocument.presentation")
        zip.add("styles.xml", """
            <office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"><office:automatic-styles><style:page-layout style:name="PM1"><style:page-layout-properties fo:page-width="28cm" fo:page-height="15.75cm"/></style:page-layout></office:automatic-styles></office:document-styles>
            """)
        zip.add("Pictures/logo.png", TestImages.png())
        zip.add("content.xml", """
            <office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0" xmlns:presentation="urn:oasis:names:tc:opendocument:xmlns:presentation:1.0" xmlns:xlink="http://www.w3.org/1999/xlink"><office:body><office:presentation>
            <draw:page draw:name="page1"><draw:frame presentation:class="title" svg:x="1cm" svg:y="1cm" svg:width="20cm" svg:height="3cm"><draw:text-box><text:p>Open formats</text:p></draw:text-box></draw:frame>
            <draw:frame svg:x="2cm" svg:y="5cm" svg:width="4cm" svg:height="2cm"><draw:image xlink:href="Pictures/logo.png"/></draw:frame>
            <presentation:notes><draw:frame presentation:class="notes"><draw:text-box><text:p>Remember the logo</text:p></draw:text-box></draw:frame></presentation:notes></draw:page>
            </office:presentation></office:body></office:document-content>
            """)
        let original = try folder.file("Open.odp", zip.data())
        var service = ImportService()
        service.keynote = KeynoteExporter.unavailable
        let prepared = try await service.prepare(original)
        let document = try DeckDocument(contentsOf: prepared.htmlURL)
        #expect(document.structure.slides.count == 1)
        #expect(document.structure.slides[0].label == "Open formats")
        #expect(document.structure.slides[0].notes == "Remember the logo")
        #expect(document.structure.canvas == CanvasSize(width: 1058, height: 595))
        #expect(document.source.contains("Open%20(Cue)%20assets/logo.png"))
    }
}
