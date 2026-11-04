/// Dragging a slide in the sidebar. Positions between slides are "gaps":
/// gap 0 is above the first slide, gap `count` below the last.
public enum SlideReorder {
    /// The gap a pointer is over: the upper half of a slide means above it.
    public static func gap(overSlide index: Int, pointerY: Double, rowHeight: Double) -> Int {
        pointerY < rowHeight / 2 ? index : index + 1
    }

    /// The slide's final position after dropping it into `gap`, or nil when
    /// that leaves it where it is (the gaps just above and below it).
    public static func destination(moving from: Int, toGap gap: Int) -> Int? {
        let to = gap > from ? gap - 1 : gap
        return to == from ? nil : to
    }

    /// Moves with the keyboard (⌥⌘↑ / ⌥⌘↓): the slide's new position, or nil at an end.
    public static func step(_ index: Int, by offset: Int, count: Int) -> Int? {
        let to = index + offset
        return (0..<count).contains(to) ? to : nil
    }
}
