import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Several slide renders in a grid, numbered, for reviewing a redesign at a
/// glance. At most `maxWidth` pixels wide so it stays a sensible size.
enum ContactSheet {
    static let maxWidth = 2400

    static func compose(_ pngs: [(number: Int, png: Data)], columns: Int, canvas: CGSize) throws -> Data {
        guard !pngs.isEmpty else { throw CueMCPError.invalid("No slides to render.") }
        let columns = max(1, min(columns, pngs.count))
        let rows = (pngs.count + columns - 1) / columns
        let gap = 24, label = 36
        let cellWidth = (maxWidth - gap * (columns + 1)) / columns
        let cellHeight = Int(Double(cellWidth) * canvas.height / max(1, canvas.width))
        let width = gap * (columns + 1) + cellWidth * columns
        let height = gap + rows * (cellHeight + label + gap)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CueMCPError.invalid("Couldn't make the contact sheet.")
        }
        context.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (index, item) in pngs.enumerated() {
            let column = index % columns, row = index / columns
            let x = gap + column * (cellWidth + gap)
            let top = gap + row * (cellHeight + label + gap)
            let frame = CGRect(x: x, y: height - top - label - cellHeight, width: cellWidth, height: cellHeight)
            if let source = CGImageSourceCreateWithData(item.png as CFData, nil),
               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                context.interpolationQuality = .high
                context.draw(image, in: frame)
            }
            drawNumber(item.number, in: context, at: CGPoint(x: x, y: height - top - label + 8))
        }
        guard let image = context.makeImage() else { throw CueMCPError.invalid("Couldn't make the contact sheet.") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw CueMCPError.invalid("Couldn't encode the contact sheet.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CueMCPError.invalid("Couldn't encode the contact sheet.") }
        return data as Data
    }

    /// The slide number in small white 7-segment digits, so the sheet needs
    /// no text rendering (CueMCP has no AppKit or Core Text).
    private static func drawNumber(_ number: Int, in context: CGContext, at origin: CGPoint) {
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
        var x = origin.x
        for digit in String(number).compactMap(\.wholeNumberValue) {
            for segment in segments[digit] { context.fill(segmentRect(segment, at: CGPoint(x: x, y: origin.y))) }
            x += 18
        }
    }

    /// Segments a–g of each digit.
    private static let segments: [[Int]] = [
        [0, 1, 2, 4, 5, 6], [2, 5], [0, 2, 3, 4, 6], [0, 2, 3, 5, 6], [1, 2, 3, 5],
        [0, 1, 3, 5, 6], [0, 1, 3, 4, 5, 6], [0, 2, 5], [0, 1, 2, 3, 4, 5, 6], [0, 1, 2, 3, 5, 6],
    ]

    /// 12 × 22 pt digit: 0 top, 1 top-left, 2 top-right, 3 middle, 4 bottom-left, 5 bottom-right, 6 bottom.
    private static func segmentRect(_ segment: Int, at origin: CGPoint) -> CGRect {
        let (w, h, t): (CGFloat, CGFloat, CGFloat) = (12, 22, 2.5)
        switch segment {
        case 0: return CGRect(x: origin.x, y: origin.y + h - t, width: w, height: t)
        case 1: return CGRect(x: origin.x, y: origin.y + h / 2, width: t, height: h / 2)
        case 2: return CGRect(x: origin.x + w - t, y: origin.y + h / 2, width: t, height: h / 2)
        case 3: return CGRect(x: origin.x, y: origin.y + h / 2 - t / 2, width: w, height: t)
        case 4: return CGRect(x: origin.x, y: origin.y, width: t, height: h / 2)
        case 5: return CGRect(x: origin.x + w - t, y: origin.y, width: t, height: h / 2)
        default: return CGRect(x: origin.x, y: origin.y, width: w, height: t)
        }
    }
}
