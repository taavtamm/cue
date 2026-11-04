/// When a show has no screen showing the presenter, Cue shows the presenter
/// view on this Mac instead, so the presenter is never left without a window
/// (and Esc, the timer and notes). This decides, after every layout change,
/// whether that fallback view should open, close or stay.
public enum FallbackPresenter: Equatable, Sendable {
    case open, close, keep

    /// `roles` are the roles of the windows the show has on real screens.
    public static func decide(roles: [DisplayRole], fallbackIsOpen: Bool) -> FallbackPresenter {
        let presenterShown = roles.contains(.presenter) || roles.contains(.confidence)
        if roles.isEmpty { return fallbackIsOpen ? .keep : .open }
        if presenterShown { return fallbackIsOpen ? .close : .keep }
        return .keep // An audience screen alone: keep whatever the presenter has.
    }
}
