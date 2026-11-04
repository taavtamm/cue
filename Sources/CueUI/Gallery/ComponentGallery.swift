import SwiftUI

/// Every shared component on one page, on the Cue ground. Wire it into a
/// debug window to review the design system; also rendered by tests.
public struct ComponentGallery: View {
    @State private var ask = ""
    @State private var search = ""
    @State private var notes = "Everything on these slides runs on the shop's own setup."
    @State private var mode = "Design"
    @State private var tab = "Animate"
    @State private var toggleA = true
    @State private var toggleB = false

    public init() {}

    public var body: some View {
        ZStack {
            CueBackground()
            VStack(alignment: .leading, spacing: 28) {
                toolbarRow
                AskBar(text: $ask, suggestions: ["Build the cards one by one", "Tighten headline"]) {}
                    .frame(width: 780)
                HStack(alignment: .top, spacing: 24) {
                    inspectorSample
                    presenterSample
                }
                launcherField
                Banner(
                    systemImage: "network",
                    message: "This deck loads fonts from fonts.googleapis.com and fonts.gstatic.com. Allow?",
                    detail: "Cue blocks the network for every deck until you allow it. Saved with this deck.",
                    actions: [.init("Allow", kind: .primary) {}, .init("Not now") {}, .init("Never") {}]
                )
                .frame(width: 900)
            }
            .padding(40)
        }
        .foregroundStyle(CueTheme.text)
    }

    private var toolbarRow: some View {
        HStack(spacing: 14) {
            IconButton("Add slide", systemImage: "plus.rectangle") {}
            PlayButton {}
            Spacer().frame(width: 20)
            SegmentedSwitch(selection: $mode, options: ["Design", "HTML", "Outline"]) { $0 }
            Button("3 Displays") {}.buttonStyle(.cue())
            Button("Rehearse") {}.buttonStyle(.cue())
            StartShowButton {}
        }
    }

    private var inspectorSample: some View {
        VStack(alignment: .leading, spacing: 14) {
            SegmentedSwitch(selection: $tab, options: ["Design", "Animate", "Notes"], fillsWidth: true) { $0 }
            SectionLabel("Typography")
            GlowTextField("Size", text: .constant("88"), style: .compact)
                .frame(height: 30)
                .padding(.horizontal, 8)
                .background(CueTheme.controlFill, in: RoundedRectangle(cornerRadius: 8))
            SectionLabel("Live content")
            Toggle("Play live content in editor", isOn: $toggleA).toggleStyle(.cue)
            Toggle("Restart animations on enter", isOn: $toggleB).toggleStyle(.cue)
            SectionLabel("Notes")
            GlowTextField(text: $notes, style: .notes)
                .frame(height: 70)
                .padding(10)
                .background(CueTheme.insetFill, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .frame(width: 296)
        .cueGlass(.panel)
    }

    private var presenterSample: some View {
        VStack(alignment: .leading, spacing: 16) {
            ElapsedTimer(elapsed: 768, target: 1500, pace: "on pace")
            HStack(spacing: 8) {
                Button { } label: { HStack(spacing: 4) { Text("Black screen"); KeyHint("B") } }
                    .buttonStyle(.cue())
                Button("Pause timer") {}.buttonStyle(.cue())
                Button("End show") {}.buttonStyle(.cue(.destructive))
            }
            Button("Next build") {}.buttonStyle(.cue(.primary, height: 52))
            HStack(spacing: 10) {
                LiveTag()
                Pill("Stage", .badge(CueTheme.destructive))
                Pill("Presenter view", .badge(CueTheme.selection))
                Pill("On stage", .status(dot: CueTheme.destructive))
            }
        }
        .padding(20)
        .cueGlass(.window)
    }

    private var launcherField: some View {
        GlowTextField("Search or Ask", text: $search, style: .launcher)
            .frame(height: 70)
            .padding(.horizontal, 48)
            .frame(width: 780, height: 110)
            .background(
                LinearGradient(colors: [Color(hex: 0x0A0A0C), Color(hex: 0x1C1C20), Color(hex: 0x4B4B52)],
                               startPoint: .top, endPoint: .bottom),
                in: Capsule()
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
    }
}

#Preview { ComponentGallery().frame(width: 1200, height: 900) }
