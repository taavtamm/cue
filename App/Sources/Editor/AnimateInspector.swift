import CueCore
import CueEditor
import CueUI
import SwiftUI

/// The slide's builds: reorder them, change their effect, build the
/// selected element in, or take a step out. Each change is one edit.
struct AnimateInspector: View {
    let session: EditorSession

    var body: some View {
        let plan = currentPlan
        SnapshotFriendlyScrollView(axis: .vertical) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Builds on this slide")
                if plan.steps.isEmpty {
                    Text("No builds. Everything appears with the slide.")
                        .font(.system(size: 12)).foregroundStyle(CueTheme.textSecondary)
                }
                ForEach(plan.steps) { step in row(step, plan: plan) }
                if !plan.isEditable {
                    Text("This deck's builds use selectors Cue can't trace to the HTML, so they're shown read-only.")
                        .font(.system(size: 11)).foregroundStyle(CueTheme.textTertiary)
                }
                addButton(plan)
                if session.liveSlides.contains(session.slide) {
                    SectionLabel("Live content").padding(.top, 8)
                    Text("Web embed · the author's own animation · loops while on stage")
                        .font(.system(size: 12)).foregroundStyle(CueTheme.textSecondary)
                }
            }
            .padding(EdgeInsets(top: 4, leading: 16, bottom: 16, trailing: 16))
        }
    }

    private var currentPlan: BuildPlan {
        let slide = session.currentSlide ?? SlideInfo(id: "", label: "", elementPath: [])
        return BuildPlan(slide: slide, map: session.document.sourceMap, tree: session.document.tree)
    }

    private func row(_ step: BuildPlan.Step, plan: BuildPlan) -> some View {
        let selected = session.selection?.inspection?.buildStep == step.id
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(step.id + 1) · \(step.title)").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text("\((step.effect ?? "fade").capitalized) · on click").font(.system(size: 11.5))
                    .foregroundStyle(CueTheme.textSecondary)
            }
            Spacer(minLength: 4)
            if plan.isEditable { controls(step, plan: plan) }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 8))
        .background(fill(selected), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? CueTheme.selection.opacity(0.4) : .clear))
    }

    private func controls(_ step: BuildPlan.Step, plan: BuildPlan) -> some View {
        HStack(spacing: 2) {
            Menu {
                ForEach(BuildPlan.effects, id: \.self) { effect in
                    Button(effect.capitalized) { update(plan) { $0.steps[step.id].effect = effect } }
                }
            } label: { Image(systemName: "wand.and.stars") }
            .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).frame(width: 24)
            .accessibilityLabel("Effect")
            smallButton("Move up", "chevron.up") { update(plan) { $0.move(step.id, by: -1) } }
            smallButton("Move down", "chevron.down") { update(plan) { $0.move(step.id, by: 1) } }
            smallButton("Remove build", "xmark") { update(plan) { $0.steps.remove(at: step.id) } }
        }
    }

    private func fill(_ selected: Bool) -> Color {
        selected ? CueTheme.selection.opacity(0.14) : Color.white.opacity(0.05)
    }

    private func smallButton(_ label: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        IconButton(label, systemImage: symbol, size: 24, iconSize: 11, action: action)
    }

    private func addButton(_ plan: BuildPlan) -> some View {
        Button {
            guard let path = session.selection?.path else { return }
            update(plan) { $0.append(path) }
        } label: {
            Label("Build selected element", systemImage: "plus").frame(maxWidth: .infinity)
        }
        .buttonStyle(.cue(height: 32))
        .disabled(session.selection == nil || !plan.isEditable)
    }

    private func update(_ plan: BuildPlan, _ change: (inout BuildPlan) -> Void) {
        var next = plan
        change(&next)
        let slide = session.slide
        Task { await session.apply(.setBuilds(slide: slide, steps: next.specs)) }
    }
}
