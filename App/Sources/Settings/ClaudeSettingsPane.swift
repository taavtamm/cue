import AppKit
import CueCore
import CueMCP
import CueUI
import SwiftUI

/// Settings › Claude: connect the user's own Claude Code or Claude Desktop
/// to Cue over MCP, see who's connected, and choose how edits land.
struct ClaudeSettingsPane: View {
    @Bindable var settings = CueSettings.shared
    let connection = ClaudeConnection.shared
    @State private var desktopResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup("Connection", footnote: "Cue never signs in with a Claude subscription. Your own Claude app "
                          + "connects to Cue, so edits run on your plan inside Anthropic's apps.") {
                SettingsRow("Status", detail: statusDetail) { Pill(statusTitle, .status(dot: statusColor)) }
                ForEach(connection.clients) { client in
                    SettingsDivider()
                    SettingsRow(client.client, detail: client.supportsSampling
                                ? "Connected · can run requests from the Ask bar directly" : "Connected") { EmptyView() }
                }
            }
            SettingsGroup("Claude Code", footnote: "Run this once in Terminal. Then, in a Claude Code session, paste "
                          + "the Ask-bar instruction below to have it serve requests you type in Cue.") {
                CopyableCode(text: ClaudeSetup.claudeCodeCommand(helperPath: connection.helperPath))
                SettingsDivider()
                CopyableCode(text: ClaudeSetup.askLoopInstruction)
            }
            SettingsGroup("Claude Desktop", footnote: desktopResult ?? "Adds Cue to Claude Desktop's MCP servers "
                          + "(the old file is backed up first). Restart Claude Desktop afterwards.") {
                CopyableCode(text: ClaudeSetup.desktopSnippet(helperPath: connection.helperPath))
                SettingsDivider()
                SettingsRow("Add to Claude Desktop") {
                    Button("Add") { addToDesktop() }.buttonStyle(.cue(.primary, height: 28))
                }
            }
            SettingsGroup("Edits", footnote: "Claude's edits show on the slide straight away and are kept, each with Undo. "
                          + "Turn this on to accept or undo every change before it's kept.") {
                SettingsSwitch("Review Claude's edits before keeping them", isOn: Binding(
                    get: { !settings.autoAcceptClaudeEdits }, set: { settings.autoAcceptClaudeEdits = !$0 }
                ))
            }
            if !connection.approvals.remembered.isEmpty {
                SettingsGroup("Clients") {
                    ForEach(connection.approvals.remembered, id: \.client) { entry in
                        SettingsRow(entry.client, detail: entry.decision == .approved ? "Allowed" : "Not allowed") {
                            Button("Revoke") { connection.revoke(entry.client) }.buttonStyle(.cue(height: 28))
                        }
                    }
                }
            }
        }
    }

    private var statusTitle: String {
        switch connection.listenerState {
        case .listening: connection.clients.isEmpty ? "Ready" : "Connected"
        case .failed: "Not available"
        case .stopped: "Off"
        }
    }

    private var statusColor: Color {
        switch connection.listenerState {
        case .listening: connection.clients.isEmpty ? CueTheme.violet : CueTheme.successBright
        case .failed: CueTheme.destructive
        case .stopped: CueTheme.textTertiary
        }
    }

    private var statusDetail: String {
        switch connection.listenerState {
        case .listening: connection.clients.isEmpty ? "Waiting for Claude to connect." : "\(connection.clients.count) connected."
        case .failed(let message): message
        case .stopped: "Cue isn't accepting Claude right now."
        }
    }

    private func addToDesktop() {
        do {
            let backup = try ClaudeSetup.addToClaudeDesktop(helperPath: connection.helperPath)
            desktopResult = "Added. " + (backup.map { "Backup: \($0.lastPathComponent). " } ?? "") + "Restart Claude Desktop."
        } catch {
            desktopResult = error.localizedDescription
        }
    }
}

/// Monospaced text with a Copy button.
struct CopyableCode: View {
    let text: String
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(text)
                .font(.system(size: 11.5, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? "Copied" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                copied = true
            }
            .buttonStyle(.cue(height: 26))
        }
        .padding(.vertical, 6)
    }
}
