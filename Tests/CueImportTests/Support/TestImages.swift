import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum TestImages {
    /// A solid-colour PNG.
    static func png(width: Int = 40, height: Int = 20, red: CGFloat = 1, green: CGFloat = 0, blue: CGFloat = 0) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    /// A PDF with pages of the given sizes in points.
    static func pdf(pages: [CGSize], to url: URL) {
        var box = CGRect(origin: .zero, size: pages[0])
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        for size in pages {
            var pageBox = CGRect(origin: .zero, size: size)
            let info = [kCGPDFContextMediaBox as String: Data(bytes: &pageBox, count: MemoryLayout<CGRect>.size)]
            context.beginPDFPage(info as CFDictionary)
            context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
            context.fill(CGRect(x: 10, y: 10, width: size.width / 2, height: size.height / 2))
            context.endPDFPage()
        }
        context.closePDF()
    }
}
