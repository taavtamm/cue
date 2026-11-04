import SwiftUI

extension EnvironmentValues {
    /// True while a view is drawn into an image (ImageRenderer) rather than a
    /// window. AppKit-backed controls such as `GlowTextField` can't draw
    /// there, so components show their text as plain labels instead.
    @Entry public var cueRendersStatically = false
}
