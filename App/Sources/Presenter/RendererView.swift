import CueRender
import SwiftUI

/// Shows an existing SlideRenderer inside SwiftUI. The renderer is owned by
/// the show session, so SwiftUI redraws never reload the deck.
struct RendererView: View {
    let renderer: SlideRenderer
    @Environment(\.isSnapshotRendering) private var isSnapshot

    var body: some View {
        // A second SwiftUI tree (ImageRenderer) would re-parent the one live
        // renderer out of its window, so snapshots draw black here and lay
        // the renderer's own snapshot on top.
        if isSnapshot { Color.black } else { RendererHost(renderer: renderer) }
    }
}

private struct RendererHost: NSViewRepresentable {
    let renderer: SlideRenderer

    func makeNSView(context: Context) -> SlideRenderer { renderer }
    func updateNSView(_ nsView: SlideRenderer, context: Context) {}
}
