import AppKit
import CoreImage
import Synchronization

/// Draws the caret's glow and haze into one bitmap, so the bloom looks the
/// same everywhere (on screen, in previews, in exports) and needs no layer
/// shadows or masks. The bar sits centred in the image with `margin` around it.
enum CaretBloomRenderer {
    struct Key: Hashable {
        let barSize: CGSize
        let scale: CGFloat
        let style: CaretStyle
    }

    /// Room around the bar for the glow to fade out, in points.
    static func margin(for style: CaretStyle) -> CGFloat { ceil(14 * style.glowScale) }

    /// Rendered blooms by size. Layers lay out off the main actor, so lock.
    private static let cache = Mutex<[Key: CGImage]>([:])

    static func image(barSize: CGSize, scale: CGFloat, style: CaretStyle) -> CGImage? {
        let key = Key(barSize: barSize, scale: scale, style: style)
        if let cached = cache.withLock({ $0[key] }) { return cached }
        guard let image = render(key) else { return nil }
        cache.withLock { cache in
            if cache.count > 32 { cache.removeAll() }
            cache[key] = image
        }
        return image
    }

    private static func render(_ key: Key) -> CGImage? {
        let margin = margin(for: key.style)
        let size = CGSize(width: key.barSize.width + margin * 2, height: key.barSize.height + margin * 2)
        let pixels = CGSize(width: ceil(size.width * key.scale), height: ceil(size.height * key.scale))
        guard pixels.width > 0, pixels.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        // Work in points, y down, like the CSS recipe.
        context.scaleBy(x: key.scale, y: key.scale)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        let bar = CGRect(origin: CGPoint(x: margin, y: margin), size: key.barSize)

        if let haze = hazeImage(bar: bar, canvas: size, key: key) {
            context.saveGState()
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(haze, in: CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
        drawGlows(in: context, bar: bar, style: key.style)
        return context.makeImage()
    }

    /// Each glow is a blurred copy of the bar. Draw the bar far off canvas
    /// and offset its shadow back, so only the soft shadow lands.
    private static func drawGlows(in context: CGContext, bar: CGRect, style: CaretStyle) {
        let away: CGFloat = 10_000
        let path = CGPath(
            roundedRect: bar.offsetBy(dx: away, dy: 0), cornerWidth: bar.width / 2, cornerHeight: bar.width / 2,
            transform: nil)
        for glow in CaretGlow.recipe {
            context.saveGState()
            // Shadow offsets ignore the CTM's flip, so y is in device space (y up).
            let offsetY = -glow.offsetY * style.glowScale
            context.setShadow(
                offset: CGSize(width: -away * contextScale(context), height: offsetY * contextScale(context)),
                blur: glow.blur * style.glowScale * contextScale(context),
                color: glow.color.withAlphaComponent(CGFloat(glow.opacity)).cgColor)
            context.addPath(path)
            context.setFillColor(NSColor.white.cgColor)
            context.fillPath()
            context.restoreGState()
        }
    }

    private static func contextScale(_ context: CGContext) -> CGFloat {
        abs(context.ctm.a)
    }

    /// The capsule haze: about 5× the bar's width, a few points taller,
    /// cool white at the top to gold at the bottom, blurred to nothing.
    private static func hazeImage(bar: CGRect, canvas: CGSize, key: Key) -> CGImage? {
        let style = key.style
        let width = bar.width * style.hazeWidthFactor
        let capsule = CGRect(
            x: bar.midX - width / 2, y: bar.minY - style.hazeOverhang,
            width: width, height: bar.height + style.hazeOverhang * 2)
        let colors = CaretGlow.hazeColors.map(\.0.cgColor) as CFArray
        let locations = CaretGlow.hazeColors.map(\.1)
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors,
                                        locations: locations) else { return nil }
        let image = CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: canvas))
        let shape = NSImage(size: canvas, flipped: true) { _ in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            cg.addPath(CGPath(roundedRect: capsule, cornerWidth: width / 2, cornerHeight: width / 2, transform: nil))
            cg.clip()
            cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: capsule.minY),
                                  end: CGPoint(x: 0, y: capsule.maxY), options: [])
            return true
        }
        var rect = CGRect(origin: .zero, size: canvas)
        guard let shapeImage = shape.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        let blurred = CIImage(cgImage: shapeImage)
            .clampedToExtent()
            .applyingGaussianBlur(sigma: style.hazeBlur)
            .cropped(to: CGRect(origin: .zero, size: CGSize(width: shapeImage.width, height: shapeImage.height)))
            .composited(over: image)
        return CIContext().createCGImage(blurred, from: blurred.extent)
    }
}
