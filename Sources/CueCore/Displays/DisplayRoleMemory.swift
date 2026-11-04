import Foundation

/// Reads and writes display roles in the sidecar, keyed by the set of
/// connected screens, so the same room gets the same roles next time.
extension CueSidecar {
    public func rememberedRoles(for displays: [DisplayInfo]) -> DisplayRoles? {
        guard let stored = displayRoles[displays.setKey] else { return nil }
        let roles = stored.compactMapValues(DisplayRole.init(rawValue:))
        return roles.isEmpty ? nil : DisplayRoles(roles)
    }

    public mutating func remember(_ roles: DisplayRoles, for displays: [DisplayInfo]) {
        let ids = Set(displays.map(\.id))
        let stored = roles.roles.filter { ids.contains($0.key) }.mapValues(\.rawValue)
        displayRoles[displays.setKey] = stored
    }

    /// Remembered roles for this set of screens, else the defaults.
    public func roles(for displays: [DisplayInfo]) -> DisplayRoles {
        rememberedRoles(for: displays)?.reconciled(with: displays) ?? .defaults(for: displays)
    }
}
