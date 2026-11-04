import CoreGraphics
import Testing
@testable import CueCore

@Suite struct DisplayRolesTests {
    let laptop = DisplayInfo(
        id: "builtin", name: "MacBook Pro", frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        pixelWidth: 3024, pixelHeight: 1964, isBuiltIn: true, isMain: true
    )
    let monitor = DisplayInfo(
        id: "lg", name: "LG UltraFine 5K", frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
        pixelWidth: 5120, pixelHeight: 2880
    )
    let ipad = DisplayInfo(
        id: "ipad", name: "iPad Pro", frame: CGRect(x: -1376, y: 0, width: 1376, height: 1032),
        pixelWidth: 2752, pixelHeight: 2064
    )

    @Test func oneScreenIsTheStage() {
        #expect(DisplayRoles.defaults(for: [laptop]).roles == ["builtin": .stage])
    }

    @Test func twoScreensPutPresenterOnTheLaptop() {
        let roles = DisplayRoles.defaults(for: [laptop, monitor])
        #expect(roles.role(of: "builtin") == .presenter)
        #expect(roles.role(of: "lg") == .stage)
    }

    @Test func threeScreensUseTheLargestAsStageAndMirrorTheRest() {
        let roles = DisplayRoles.defaults(for: [laptop, monitor, ipad])
        #expect(roles.stageID == "lg")
        #expect(roles.role(of: "ipad") == .mirror)
    }

    @Test func pickingStageTurnsTheOldStageIntoMirror() {
        var roles = DisplayRoles.defaults(for: [laptop, monitor, ipad])
        roles.assign(.stage, to: "ipad")
        #expect(roles.stageID == "ipad")
        #expect(roles.role(of: "lg") == .mirror)
        #expect(roles.displays(with: .stage).count == 1)
    }

    @Test func initKeepsOnlyOneStage() {
        let roles = DisplayRoles(["a": .stage, "b": .stage])
        #expect(roles.displays(with: .stage) == ["a"])
        #expect(roles.role(of: "b") == .mirror)
    }

    @Test func unpluggingTheStagePromotesAMirror() {
        var roles = DisplayRoles.defaults(for: [laptop, monitor, ipad])
        roles.assign(.mirror, to: "ipad")
        let after = roles.reconciled(with: [laptop, ipad])
        #expect(after.stageID == "ipad")
        #expect(after.role(of: "builtin") == .presenter)
        #expect(after.roles["lg"] == nil)
    }

    @Test func pluggingInAKnownScreenRestoresItsRole() {
        var memory = DisplayRoles.defaults(for: [laptop, monitor, ipad])
        memory.assign(.confidence, to: "ipad")
        let current = DisplayRoles.defaults(for: [laptop, monitor])
        let after = current.reconciled(with: [laptop, monitor, ipad], remembered: memory)
        #expect(after.role(of: "ipad") == .confidence)
        #expect(after.role(of: "lg") == .stage)
    }

    @Test func pluggingInAnUnknownScreenLeavesItOff() {
        let current = DisplayRoles.defaults(for: [laptop, monitor])
        let after = current.reconciled(with: [laptop, monitor, ipad])
        #expect(after.role(of: "ipad") == .off)
    }

    @Test func aRememberedStageDoesNotStealTheCurrentStage() {
        let memory = DisplayRoles(["ipad": .stage])
        let current = DisplayRoles.defaults(for: [laptop, monitor])
        let after = current.reconciled(with: [laptop, monitor, ipad], remembered: memory)
        #expect(after.stageID == "lg")
        #expect(after.role(of: "ipad") == .mirror)
    }

    @Test func rolesAreRememberedPerDisplaySet() {
        var sidecar = CueSidecar()
        var roles = DisplayRoles.defaults(for: [laptop, monitor])
        roles.assign(.confidence, to: "builtin")
        sidecar.remember(roles, for: [laptop, monitor])
        #expect(sidecar.roles(for: [laptop, monitor]).role(of: "builtin") == .confidence)
        #expect(sidecar.roles(for: [monitor, laptop]).role(of: "builtin") == .confidence)
        // Another room: defaults, not the remembered ones.
        #expect(sidecar.roles(for: [laptop, ipad]).role(of: "builtin") == .presenter)
    }

    @Test func layoutChangeClosesUnpluggedAndOpensNewWindows() {
        let current: [String: DisplayRole] = ["builtin": .presenter, "lg": .stage]
        let next = DisplayRoles(["builtin": .presenter, "ipad": .stage])
        let change = DisplayLayoutChange(from: current, to: next)
        #expect(change.close == ["lg"])
        #expect(change.open == ["ipad": .stage])
    }

    @Test func layoutChangeReopensAScreenThatChangedRole() {
        let change = DisplayLayoutChange(from: ["lg": .stage], to: DisplayRoles(["lg": .off]))
        #expect(change.close == ["lg"])
        #expect(change.open.isEmpty)
        #expect(DisplayLayoutChange(from: ["lg": .stage], to: DisplayRoles(["lg": .stage])).isEmpty)
    }
}
