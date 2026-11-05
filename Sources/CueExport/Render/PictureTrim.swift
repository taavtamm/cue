import CoreGraphics
import Foundation

/// Cuts a see-through picture down to what it actually shows.
enum PictureTrim {
    /// The smallest rectangle (in the image's pixels, top-left origin) holding
    /// every pixel more than faintly visible, or nil when the picture is empty.
    static func visibleBounds(_ image: CGImage, threshold: UInt8 = 8) -> CGRect? {
        let width = image.width, height = image.height
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drawn = alpha.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return CGRect(x: 0, y: 0, width: width, height: height) }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where alpha[row + x] > threshold {
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        // The bitmap's rows run top to bottom, as the image's do.
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// The visible part of `image` (a picture of a canvas `canvasWidth` pixels
    /// wide), and where it sits in canvas pixels; nil when nothing shows.
    static func trimmed(_ image: CGImage, canvasWidth: Double) -> (image: CGImage, box: CGRect)? {
        guard let bounds = visibleBounds(image) else { return nil }
        let padded = bounds.insetBy(dx: -2, dy: -2).intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let cut = image.cropping(to: padded) else { return nil }
        let toCanvas = canvasWidth / Double(image.width)
        return (cut, CGRect(x: padded.minX * toCanvas, y: padded.minY * toCanvas,
                            width: padded.width * toCanvas, height: padded.height * toCanvas))
    }
}
