import Foundation

/// The role of each connected screen. Enforces one Stage at a time.
public struct DisplayRoles: Sendable, Equatable, Codable {
    public private(set) var roles: [String: DisplayRole]

    public init(_ roles: [String: DisplayRole] = [:]) {
        self.init(roles, preferredStage: nil)
    }

    init(_ roles: [String: DisplayRole], preferredStage: String?) {
        self.roles = roles
        normaliseStage(keeping: preferredStage)
    }

    public func role(of displayID: String) -> DisplayRole { roles[displayID] ?? .off }

    public var stageID: String? { roles.first { $0.value == .stage }?.key }

    public func displays(with role: DisplayRole) -> [String] {
        roles.filter { $0.value == role }.map(\.key).sorted()
    }

    /// Picking Stage turns the old Stage into a Mirror.
    public mutating func assign(_ role: DisplayRole, to displayID: String) {
        if role == .stage, let old = stageID, old != displayID { roles[old] = .mirror }
        roles[displayID] = role
    }

    /// Sensible roles for screens Cue hasn't seen together before:
    /// one screen is the stage; with more, the built-in (or menu-bar) screen
    /// is the presenter, the largest other screen the stage, the rest mirrors.
    public static func defaults(for displays: [DisplayInfo]) -> DisplayRoles {
        guard displays.count > 1 else {
            return DisplayRoles(Dictionary(uniqueKeysWithValues: displays.map { ($0.id, .stage) }))
        }
        let presenter = displays.first(where: \.isBuiltIn) ?? displays.first(where: \.isMain) ?? displays[0]
        let others = displays.filter { $0.id != presenter.id }
        let stage = others.max { $0.area < $1.area } ?? others[0]
        var roles = [presenter.id: DisplayRole.presenter, stage.id: .stage]
        for display in others where display.id != stage.id { roles[display.id] = .mirror }
        return DisplayRoles(roles)
    }

    /// Roles for the screens connected right now. Keeps known roles, gives new
    /// screens their remembered role (else Off), drops removed screens, and if
    /// the stage was unplugged promotes a mirror so the audience keeps a slide.
    public func reconciled(with displays: [DisplayInfo], remembered: DisplayRoles? = nil) -> DisplayRoles {
        let ids = Set(displays.map(\.id))
        var next: [String: DisplayRole] = [:]
        for id in ids.sorted() {
            next[id] = roles[id] ?? remembered?.roles[id] ?? .off
        }
        var result = DisplayRoles(next, preferredStage: stageID)
        if result.stageID == nil, let mirror = result.displays(with: .mirror).first {
            result.roles[mirror] = .stage
        }
        return result
    }

    /// Keeps exactly one stage: the preferred one, else the first in id order.
    private mutating func normaliseStage(keeping preferred: String?) {
        let stages = roles.filter { $0.value == .stage }.map(\.key).sorted()
        guard stages.count > 1 else { return }
        let keep = preferred.flatMap { stages.contains($0) ? $0 : nil } ?? stages[0]
        for id in stages where id != keep { roles[id] = .mirror }
    }
}
