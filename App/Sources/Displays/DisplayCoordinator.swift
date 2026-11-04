import AppKit
import CueCore
import Observation

/// Which screen shows what, for one deck. Watches screens being plugged in
/// and out, remembers roles per set of screens in the deck's sidecar, and
/// tells a running show when its windows must change.
@MainActor @Observable
final class DisplayCoordinator {
    private(set) var displays: [DisplayInfo] = []
    private(set) var roles = DisplayRoles()
    /// The screen selected in the Displays window.
    var selectedID: String?
    /// Line mirrored animations up after each slide change.
    var keepsAnimationsInSync = UserDefaults.standard.object(forKey: Keys.sync) as? Bool ?? true {
        didSet { UserDefaults.standard.set(keepsAnimationsInSync, forKey: Keys.sync) }
    }
    /// Set by a running show. Mid-show, new screens get their remembered role or Off.
    @ObservationIgnored var onLayoutChange: (() -> Void)?
    @ObservationIgnored var isPresenting = false
    /// Focus / Do Not Disturb is known to be off. Cleared when the user dismisses the hint.
    var showsFocusWarning = false

    private let sidecarURL: URL
    private let readDisplays: @MainActor () -> [DisplayInfo]
    @ObservationIgnored private var observer: NSObjectProtocol?

    private enum Keys { static let sync = "keepsAnimationsInSync" }

    init(sidecarURL: URL, readDisplays: @escaping @MainActor () -> [DisplayInfo] = ScreenCatalog.displays) {
        self.sidecarURL = sidecarURL
        self.readDisplays = readDisplays
        displays = readDisplays()
        roles = sidecar.roles(for: displays)
        selectedID = roles.stageID ?? displays.first?.id
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
    }

    func role(of displayID: String) -> DisplayRole { roles.role(of: displayID) }

    /// Checks Focus when the Displays window opens. Injected for testing.
    func refreshFocus(_ state: FocusHint.StateProvider = FocusHint.systemState) async {
        showsFocusWarning = FocusHint.shouldWarn(await state())
    }

    func display(_ displayID: String) -> DisplayInfo? { displays.first { $0.id == displayID } }

    var selected: DisplayInfo? { selectedID.flatMap(display) }

    /// Picking Stage turns the old Stage into Mirror. Remembered for this set of screens.
    func assign(_ role: DisplayRole, to displayID: String) {
        roles.assign(role, to: displayID)
        remember()
        onLayoutChange?()
    }

    /// The screens changed. Before a show, use what this room had last time,
    /// else defaults. During a show, keep what's running and add new screens
    /// with their remembered role, or Off.
    func screensChanged() {
        let current = readDisplays()
        guard current != displays else { return }
        displays = current
        let remembered = sidecar.rememberedRoles(for: current)
        if isPresenting {
            roles = roles.reconciled(with: current, remembered: remembered)
        } else {
            roles = remembered?.reconciled(with: current) ?? .defaults(for: current)
        }
        if selectedID.flatMap(display) == nil { selectedID = roles.stageID ?? current.first?.id }
        onLayoutChange?()
    }

    func count(of role: DisplayRole) -> Int { roles.displays(with: role).count }

    /// "2 audience screens · 1 presenter · 0 confidence monitors"
    var summary: String {
        let audience = count(of: .stage) + count(of: .mirror)
        let presenter = count(of: .presenter)
        let confidence = count(of: .confidence)
        return "\(audience) audience screen\(audience == 1 ? "" : "s") · \(presenter) presenter · "
            + "\(confidence) confidence monitor\(confidence == 1 ? "" : "s")"
    }

    private var sidecar: CueSidecar { (try? CueSidecar.load(from: sidecarURL)) ?? CueSidecar() }

    private func remember() {
        let roles = roles, displays = displays
        do {
            try CueSidecar.update(at: sidecarURL) { $0.remember(roles, for: displays) }
        } catch {
            NSLog("Cue: couldn't save display roles: %@", error.localizedDescription)
        }
    }
}
