import SwiftUI
import UniformTypeIdentifiers

/// Accepts dropped files. Left off in Debug snapshots: ImageRenderer can't
/// draw a view that is a drop target and renders a placeholder instead.
struct DeckDropTarget: ViewModifier {
    let isEnabled: Bool
    @Binding var isTargeted: Bool
    let perform: @MainActor ([NSItemProvider]) -> Bool

    init(isEnabled: Bool, isTargeted: Binding<Bool>, perform: @escaping @MainActor ([NSItemProvider]) -> Bool) {
        self.isEnabled = isEnabled
        self._isTargeted = isTargeted
        self.perform = perform
    }

    func body(content: Content) -> some View {
        if isEnabled {
            content.onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in perform(providers) }
        } else {
            content
        }
    }
}
