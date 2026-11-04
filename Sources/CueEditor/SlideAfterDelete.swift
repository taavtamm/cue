/// Which slide to show after deleting one: the slide you were looking at
/// (one earlier if a slide above it went), or the next one along (the new
/// last slide) if it was the one deleted.
public enum SlideAfterDelete {
    public static func index(deleting deleted: Int, current: Int, countBefore: Int) -> Int {
        let target = deleted < current ? current - 1 : min(current, countBefore - 2)
        return max(0, target)
    }
}
