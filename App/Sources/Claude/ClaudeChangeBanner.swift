import CueCore
import CueEditor
import CueUI
import SwiftUI

/// Claude's latest change on the canvas. Normally a short notice, "Claude
/// changed … · Undo", that fades after a few seconds: the edit is already
/// kept. With reviewing on (Settings › Claude) a waiting change shows its
/// before/after with Accept and Undo until the user picks one.
struct ClaudeChangeBanner: View {
    let session: EditorSession
    @State private var showsList = false
    @State private var error: String?
    /// The kept change whose notice has faded.
    @State private var faded: String?

    static let noticeSeconds = 8

    var body: some View {
        if let change = session.claudeChanges.latestUndoable, change.status == .pending || change.id != faded {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").foregroundStyle(CueTheme.violet)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.summary).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(subtitle(change)).font(.system(size: 11)).foregroundStyle(CueTheme.textTertiary)
                    }
                    Spacer(minLength: 8)
                    Button("All changes") { showsList.toggle() }
                        .buttonStyle(.cue(height: 28))
                        .popover(isPresented: $showsList) { ClaudeChangeList(session: session) }
                    Button("Undo") { revert(change) }.buttonStyle(.cue(height: 28))
                    if change.status == .pending {
                        Button("Accept") { accept(change) }.buttonStyle(.cue(.primary, height: 28))
                    }
                }
                if change.status == .pending { ChangeDiff(excerpt: change.excerpts.first) }
                if let error { Text(error).font(.system(size: 11)).foregroundStyle(CueTheme.destructiveText) }
            }
            .padding(12)
            .cueGlass(.panel)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .transition(.opacity)
            .task(id: change.id) { await fadeKept(change) }
        }
    }

    private func subtitle(_ change: ChangeSet) -> String {
        let slide = change.slide.map { "Slide \($0 + 1) · " } ?? ""
        let more = session.claudeChanges.pending.count - 1
        return slide + "from \(change.client)" + (more > 0 ? " · \(more) more waiting" : "")
    }

    /// A kept change only needs a moment's notice; Undo stays in All changes and ⌘Z.
    private func fadeKept(_ change: ChangeSet) async {
        guard change.status == .accepted else { return }
        try? await Task.sleep(for: .seconds(Self.noticeSeconds))
        withAnimation(.easeOut(duration: 0.3)) { faded = change.id }
    }

    private func accept(_ change: ChangeSet) {
        do { try session.acceptClaudeChange(change.id); error = nil } catch { self.error = error.localizedDescription }
    }

    private func revert(_ change: ChangeSet) {
        Task {
            do { try await session.revertClaudeChange(change.id); error = nil } catch { self.error = error.localizedDescription }
        }
    }
}

/// Before → after for one changed region, shortened.
struct ChangeDiff: View {
    let excerpt: ChangeSet.Excerpt?

    var body: some View {
        if let excerpt {
            VStack(alignment: .leading, spacing: 3) {
                line("−", excerpt.before, CueTheme.destructiveText)
                line("+", excerpt.after, CueTheme.successBright)
            }
            .font(.system(size: 11, design: .monospaced))
        }
    }

    private func line(_ sign: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(sign).foregroundStyle(color)
            Text(text.isEmpty ? "(nothing)" : text).foregroundStyle(CueTheme.textSecondary).lineLimit(2)
        }
    }
}

/// Every change set in this window, newest first.
struct ClaudeChangeList: View {
    let session: EditorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Changes from Claude")
            if session.claudeChanges.all.isEmpty {
                Text("No changes yet.").font(.system(size: 12)).foregroundStyle(CueTheme.textTertiary)
            }
            ForEach(session.claudeChanges.all.reversed()) { change in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(change.summary).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                        Spacer()
                        if change.status == .pending || change.status == .accepted {
                            Button("Undo") { Task { try? await session.revertClaudeChange(change.id) } }
                                .buttonStyle(.cue(height: 24))
                        }
                        Pill(label(change.status), .status(dot: color(change.status)))
                    }
                    ChangeDiff(excerpt: change.excerpts.first)
                }
            }
        }
        .padding(14)
        .frame(width: 380)
        .foregroundStyle(CueTheme.text)
    }

    private func label(_ status: ChangeSet.Status) -> String {
        switch status {
        case .pending: "Waiting"
        case .accepted: "Kept"
        case .reverted: "Undone"
        case .superseded: "Edited since"
        }
    }

    private func color(_ status: ChangeSet.Status) -> Color {
        switch status {
        case .pending: CueTheme.violet
        case .accepted: CueTheme.successBright
        case .reverted, .superseded: CueTheme.textTertiary
        }
    }
}
