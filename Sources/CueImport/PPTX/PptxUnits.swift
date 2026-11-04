import Foundation

/// DrawingML units. 914 400 EMU per inch; CSS has 96 px per inch.
enum PptxUnits {
    static let emuPerPixel = 9525.0
    /// Font sizes are in hundredths of a point; 1 pt = 4/3 px.
    static func pixels(hundredthsOfPoint value: Double) -> Double { value / 100 * 96 / 72 }
    /// Angles are in 60 000ths of a degree.
    static func degrees(_ value: Double) -> Double { value / 60_000 }
}

/// Maps a group's child coordinates (EMU) to CSS pixels inside its box.
struct PptxSpace {
    var originX = 0.0, originY = 0.0
    var scaleX = 1.0, scaleY = 1.0

    static let slide = PptxSpace()

    func rect(offX: Double, offY: Double, width: Double, height: Double) -> Rect {
        Rect(
            x: (offX - originX) * scaleX / PptxUnits.emuPerPixel,
            y: (offY - originY) * scaleY / PptxUnits.emuPerPixel,
            width: width * scaleX / PptxUnits.emuPerPixel,
            height: height * scaleY / PptxUnits.emuPerPixel
        )
    }

    /// The space for children of a group whose `xfrm` has chOff/chExt.
    func child(of xfrm: XNode) -> PptxSpace {
        let ext = xfrm.child("ext"), chExt = xfrm.child("chExt"), chOff = xfrm.child("chOff")
        let sx = ratio(ext?.double("cx"), chExt?.double("cx")), sy = ratio(ext?.double("cy"), chExt?.double("cy"))
        return PptxSpace(
            originX: chOff?.double("x") ?? 0, originY: chOff?.double("y") ?? 0,
            scaleX: scaleX * sx, scaleY: scaleY * sy
        )
    }

    private func ratio(_ a: Double?, _ b: Double?) -> Double {
        guard let a, let b, b != 0 else { return 1 }
        return a / b
    }
}
