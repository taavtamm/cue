import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CueCore

/// Encoding fallbacks, EXIF-oriented images and the shared parser.
@Suite("Decoding, images and parsing")
struct DecodingAndImageTests {
    private func write(_ data: Data) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cue-decode-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("deck.html")
        try data.write(to: url)
        return url
    }

    @Test func declaredUTF16IsReadAsUTF8() throws {
        let data = Data(#"<html><head><meta charset="utf-16"></head><body><p>Café</p></body></html>"#.utf8)
        let (text, encoding) = try SourceDecoding.decode(data)
        #expect(encoding == .utf8)
        #expect(text.contains("Café"))
    }

    @Test func undefinedWindows1252BytesStillOpen() throws {
        var data = Data(#"<html><head><meta charset="windows-1252"></head><body><p>"#.utf8)
        data.append(contentsOf: [0x81, 0xE9, 0x9D])
        data.append(Data("</p></body></html>".utf8))
        let (text, encoding) = try SourceDecoding.decode(data)
        #expect(encoding == .isoLatin1)
        #expect(text.contains("\u{81}é\u{9D}"))

        // Byte-identical when unchanged; the odd bytes survive an edit too.
        let url = try write(data)
        var document = try DeckDocument(contentsOf: url)
        #expect(try document.encodedData() == data)
        let paragraph = try Editing.path(in: document, tag: "p")
        _ = try document.apply(.setAttribute(paragraph, name: "title", value: "x"))
        let saved = try document.encodedData()
        #expect(saved.firstRange(of: Data([0x81, 0xE9, 0x9D])) != nil)
        #expect(String(data: saved, encoding: .isoLatin1)?.contains(#"<p title="x">"#) == true)
    }

    @Test func utf16WithAByteOrderMarkStillRoundTrips() throws {
        let html = "<html><body><p>Hi</p></body></html>"
        let data = Data([0xFF, 0xFE]) + html.data(using: .utf16LittleEndian)!
        var document = try DeckDocument(contentsOf: try write(data))
        #expect(try document.encodedData() == data)
        let paragraph = try Editing.path(in: document, tag: "p")
        _ = try document.apply(.setAttribute(paragraph, name: "title", value: "x"))
        let saved = try document.encodedData()
        #expect(saved.starts(with: [0xFF, 0xFE]))
        #expect(saved.dropFirst(2).starts(with: Array("<html>".data(using: .utf16LittleEndian)!)))
    }

    /// A 400 × 100 JPEG tagged "rotate 90°" (EXIF orientation 6) displays as 100 × 400.
    private func rotatedJPEG(width: Int = 400, height: Int = 100) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0.5, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let type = UTType.jpeg.identifier as CFString
        let destination = try #require(CGImageDestinationCreateWithData(data, type, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: 6] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func smallRotatedPhotosReportTheirDisplayedSize() throws {
        let embedded = try ImageEmbedder(canvas: CGSize(width: 1920, height: 1080)).embed(rotatedJPEG())
        #expect(embedded.pixelSize == CGSize(width: 100, height: 400))
        #expect(embedded.note == nil)
    }

    @Test func scaledRotatedPhotosAreTurnedUpright() throws {
        // Canvas 100 × 100: at most 200 × 200, so the upright 100 × 400 becomes 50 × 200.
        let embedded = try ImageEmbedder(canvas: CGSize(width: 100, height: 100)).embed(rotatedJPEG())
        #expect(embedded.pixelSize == CGSize(width: 50, height: 200))
        let base64 = try #require(embedded.dataURI.split(separator: ",").last)
        let bytes = try #require(Data(base64Encoded: String(base64)))
        let source = try #require(CGImageSourceCreateWithData(bytes as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 50 && image.height == 200)
    }

    @Test func sharedParserMatchesAFreshOne() throws {
        let html = "<html><body><section><h1>A</h1><p>B</p></section></body></html>"
        let fresh = try HTMLParser().parse(html)
        for _ in 0..<3 {
            let shared = try HTMLParserPool.shared.parse(html)
            #expect(shared.descendants.map(\.tag) == fresh.descendants.map(\.tag))
        }
    }

    @Test func sharedParserWorksFromManyThreads() async throws {
        let html = "<html><body><section><h1>A</h1></section></body></html>"
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<16 {
                group.addTask { try HTMLParserPool.shared.parse(html).descendants.count }
            }
            let counts = try await group.reduce(into: [Int]()) { $0.append($1) }
            #expect(Set(counts).count == 1)
        }
    }
}
