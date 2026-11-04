import CueCore
import CueUI
import SwiftUI

/// Choose what each screen shows during the show.
struct DisplaysView: View {
    let coordinator: DisplayCoordinator
    let onRehearse: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 16) {
                DisplayArrangementView(coordinator: coordinator)
                rolePanel.frame(width: 380)
            }
            .padding(.horizontal, 16)
            footer
        }
        .foregroundStyle(CueTheme.text)
        .cueGlass(.window)
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Displays").font(.system(size: 15, weight: .semibold))
                Text("Choose what each screen shows during the show")
                    .font(.system(size: 12)).foregroundStyle(CueTheme.textTertiary)
            }
            Spacer()
            Text("Detected \(coordinator.displays.count) display\(coordinator.displays.count == 1 ? "" : "s")"
                 + " · arrangement from System Settings")
                .font(.system(size: 12)).foregroundStyle(CueTheme.textTertiary)
        }
        .padding(.leading, 92) // Clear of the window's traffic lights.
        .padding(.trailing, 22)
        .frame(height: 64)
    }

    @ViewBuilder private var rolePanel: some View {
        if let display = coordinator.selected {
            DisplayRolePanel(coordinator: coordinator, display: display)
        } else {
            Text("No display selected").foregroundStyle(CueTheme.textSecondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if coordinator.showsFocusWarning {
                FocusHint.banner { coordinator.showsFocusWarning = false }
                    .frame(maxWidth: 560)
            } else {
                Text(coordinator.summary).font(.system(size: 12.5)).foregroundStyle(CueTheme.textSecondary)
            }
            Spacer()
            Button("Rehearse on this Mac", action: onRehearse).buttonStyle(.cue(.glass, height: 40))
            StartShowButton(action: onStart)
                .disabled(coordinator.roles.stageID == nil)
                .help(coordinator.roles.stageID == nil ? "Give one display the Stage role first" : "Start show")
        }
        .padding(.horizontal, 22)
        .frame(height: 84)
    }
}

/// The selected screen's name and its role choices.
struct DisplayRolePanel: View {
    let coordinator: DisplayCoordinator
    let display: DisplayInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(display.name).font(.system(size: 18, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(CueTheme.textTertiary)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 6) {
                ForEach(DisplayRole.allCases) { role in
                    RadioCard(role.title, detail: role.summary, dot: role.color,
                              isOn: coordinator.role(of: display.id) == role) {
                        coordinator.assign(role, to: display.id)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Role")
            InsetPanel {
                Toggle("Keep animations in sync across screens", isOn: syncBinding)
                    .toggleStyle(.cue)
                    .font(.system(size: 13))
                    .help("Lines mirrored screens up with the stage after each slide change")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            Spacer(minLength: 0)
        }
    }

    private var detail: String {
        let kind = display.isBuiltIn ? "Built-in" : (display.isMain ? "Main display" : "External")
        return "\(kind) · \(display.resolutionText)"
    }

    private var syncBinding: Binding<Bool> {
        Binding(get: { coordinator.keepsAnimationsInSync }, set: { coordinator.keepsAnimationsInSync = $0 })
    }
}
