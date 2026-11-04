// Run from App/Resources/AppIcon.icon/Assets: `swift ../../../../docs/icon/generate-layers.swift`
// Generates Cue icon layer artwork for the Icon Composer document.
// Coordinates come from CueIcon.dc.html, rescaled from its 824px tile to 1024.
import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let k = 1024.0 / 824.0
let glowColors: [UInt32] = [0xff5fa2, 0xb36bff, 0x5b8cff, 0x38e1ff, 0x5dffb0, 0xffd25e, 0xff7a59, 0xff5fa2]
let space = CGColorSpace(name: CGColorSpace.displayP3)!


func context() -> CGContext {
    let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip so y grows downward, matching the CSS design coordinates.
    c.translateBy(x: 0, y: CGFloat(size)); c.scaleBy(x: 1, y: -1)
    return c
}

/// CSS-style conic gradient: starts at `startDegrees` from 12 o'clock and runs clockwise.
func drawConic(_ c: CGContext, center: CGPoint, startDegrees: Double) {
    let steps = 720
    for i in 0..<steps {
        let t = Double(i) / Double(steps)
        let seg = t * Double(glowColors.count - 1)
        let a = glowColors[Int(seg)], b = glowColors[min(Int(seg) + 1, glowColors.count - 1)]
        let f = seg - floor(seg)
        func ch(_ h: UInt32, _ s: UInt32) -> Double { Double((h >> s) & 255) / 255 }
        let col = CGColor(srgbRed: ch(a,16) + (ch(b,16) - ch(a,16)) * f, green: ch(a,8) + (ch(b,8) - ch(a,8)) * f,
                          blue: ch(a,0) + (ch(b,0) - ch(a,0)) * f, alpha: 1)
        let a0 = (startDegrees + t * 360 - 90) * .pi / 180
        let a1 = (startDegrees + (t + 1.5 / Double(steps)) * 360 - 90) * .pi / 180
        c.move(to: center)
        c.addArc(center: center, radius: 1500, startAngle: a0, endAngle: a1, clockwise: false)
        c.closePath(); c.setFillColor(col); c.fillPath()
    }
}

func blurred(_ image: CGImage, radius: Double, opacity: Double) -> CGImage {
    let ci = CIImage(cgImage: image).clampedToExtent()
        .applyingGaussianBlur(sigma: radius / 2)
        .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        .applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)])
    return CIContext(options: [.workingColorSpace: space]).createCGImage(ci, from: ci.extent)!
}

func save(_ image: CGImage, _ name: String) {
    let url = URL(fileURLWithPath: name)
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, image, nil); CGImageDestinationFinalize(d)
}

// Glow blob behind the triangle: an ellipse filled with the rotating conic gradient, heavily blurred.
do {
    let c = context()
    let rect = CGRect(x: 190 * k, y: 200 * k, width: 470 * k, height: 440 * k)
    c.addEllipse(in: rect); c.clip()
    drawConic(c, center: CGPoint(x: rect.midX, y: rect.midY), startDegrees: 200)
    save(blurred(c.makeImage()!, radius: 70 * k, opacity: 0.95), "glow.png")
}

// Rainbow rim: a 10px conic-gradient ring hugging the tile edge, softly blurred.
do {
    let c = context()
    let outer = CGRect(x: 0, y: 0, width: size, height: size)
    let r = 186 * k
    c.addPath(CGPath(roundedRect: outer, cornerWidth: r, cornerHeight: r, transform: nil))
    c.addPath(CGPath(roundedRect: outer.insetBy(dx: 12 * k, dy: 12 * k), cornerWidth: r - 12 * k,
                     cornerHeight: r - 12 * k, transform: nil))
    c.clip(using: .evenOdd)
    drawConic(c, center: CGPoint(x: 512, y: 512), startDegrees: 200)
    save(blurred(c.makeImage()!, radius: 8 * k, opacity: 0.6), "rim.png")
}
print("ok")
