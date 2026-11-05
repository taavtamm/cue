import CueCore
import CueEditor
import CueUI
import SwiftUI

/// With reviewing on (Settings › Claude), Claude's latest waiting change on
/// the canvas: its before/after with Accept and Undo. Kept changes (the
/// default) are announced in the Ask bar's status line instead.
struct ClaudeChangeBanner: View {
    let session: EditorSession
    @State private var showsList = false
    @State private var error: String?

    var body: some View {
        // Kept changes show in the Ask bar's status line; this banner is for reviewing.
        if let change = session.claudeChanges.latestPending {
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
                    Button("Accept") { accept(change) }.buttonStyle(.cue(.primary, height: 28))
                }
                ChangeDiff(excerpt: change.excerpts.first)
                if let error { Text(error).font(.system(size: 11)).foregroundStyle(CueTheme.destructiveText) }
            }
            .padding(12)
            .cueGlass(.panel)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .transition(.opacity)
        }
    }

    private func subtitle(_ change: ChangeSet) -> String {
        let slide = change.slide.map { "Slide \($0 + 1) · " } ?? ""
        let more = session.claudeChanges.pending.count - 1
        return slide + "from \(change.client)" + (more > 0 ? " · \(more) more waiting" : "")
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
