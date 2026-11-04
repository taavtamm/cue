import SwiftUI

extension EnvironmentValues {
    /// True while a Debug snapshot draws the view with ImageRenderer, which
    /// can't draw scroll views. Scrolling panels lay out flat instead.
    @Entry var isSnapshotRendering = false
}

/// A scroll view that lays its content out flat during snapshots.
struct SnapshotFriendlyScrollView<Content: View>: View {
    let axis: Axis.Set
    @ViewBuilder let content: () -> Content
    @Environment(\.isSnapshotRendering) private var isSnapshot

    var body: some View {
        if isSnapshot {
            // An overlay never changes the size of what it sits on, so wide content can't widen the layout.
            Color.clear
                .overlay(alignment: .topLeading) {
                    content().fixedSize(horizontal: axis == .horizontal, vertical: false)
                }
                .clipped()
        } else {
            ScrollView(axis, showsIndicators: false, content: content)
        }
    }
}
