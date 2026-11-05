/// The presenter must never be left without a window (notes, timer, Esc).
/// When no screen shows the presenter view, Cue shows it on the main screen
/// instead of that screen's Off cover. Pure, so the rule is testable.
public enum FallbackPresenter {
    /// The roles a show should actually use. `active` carries the decision
    /// between calls: it turns on when every screen is Off, stays on when an
    /// audience screen is added (the presenter still needs their view), and
    /// turns off once a real presenter or confidence screen exists.
    public static func roles(_ chosen: DisplayRoles, mainID: String?, active: inout Bool) -> DisplayRoles {
        let shown = chosen.roles.values.filter { $0 != .off }
        if shown.isEmpty { active = true }
        if shown.contains(.presenter) || shown.contains(.confidence) { active = false }
        guard active, let mainID, chosen.roles[mainID] == .off else { return chosen }
        var roles = chosen
        roles.assign(.presenter, to: mainID)
        return roles
    }
}
