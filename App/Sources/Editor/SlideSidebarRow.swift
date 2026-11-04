import AppKit
import CueEditor
import CueUI
import SwiftUI
import UniformTypeIdentifiers

/// One slide in the sidebar that can be dragged to a new place. While a
/// slide is dragged over it, a bar shows the gap it would drop into.
struct SlideSidebarRow<Cell: View>: View {
    let index: Int
    let count: Int
    @Binding var gap: Int?
    let cell: Cell
    /// Called with the dragged slide and the gap it was dropped into.
    let onDrop: (_ from: Int, _ gap: Int) -> Void
    @State private var height: CGFloat = 120

    var body: some View {
        cell
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .overlay(alignment: .top) {
                if gap == index { DropIndicator().offset(y: -3) }
            }
            .overlay(alignment: .bottom) {
                if index == count - 1, gap == count { DropIndicator().offset(y: 3) }
            }
            .onDrag { NSItemProvider(object: SlideDragPayload.string(for: index) as NSString) }
            .onDrop(of: [.plainText], delegate: SlideDropDelegate(index: index, height: height, gap: $gap, onDrop: onDrop))
    }
}

/// The dragged slide travels as plain text, `cue-slide:<index>`.
enum SlideDragPayload {
    static func string(for index: Int) -> String { "cue-slide:\(index)" }

    static func index(from string: String) -> Int? {
        guard string.hasPrefix("cue-slide:") else { return nil }
        return Int(string.dropFirst("cue-slide:".count))
    }
}

/// Tracks which gap the pointer is over and performs the drop.
struct SlideDropDelegate: DropDelegate {
    let index: Int
    let height: CGFloat
    @Binding var gap: Int?
    let onDrop: (_ from: Int, _ gap: Int) -> Void

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.plainText]) }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let over = SlideReorder.gap(overSlide: index, pointerY: info.location.y, rowHeight: height)
        if over != gap { withAnimation(.easeOut(duration: 0.12)) { gap = over } }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if gap == index || gap == index + 1 { withAnimation(.easeOut(duration: 0.12)) { gap = nil } }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let target = gap, let provider = info.itemProviders(for: [.plainText]).first else { return false }
        gap = nil
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String, let from = SlideDragPayload.index(from: text) else { return }
            Task { @MainActor in onDrop(from, target) }
        }
        return true
    }
}
