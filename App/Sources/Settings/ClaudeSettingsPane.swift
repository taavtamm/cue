import CueUI
import SwiftUI

/// Placeholder until the MCP milestone adds the connection settings.
struct ClaudeSettingsPane: View {
    var body: some View {
        SettingsGroup(footnote: "Cue never signs in with a Claude subscription. Your own Claude app connects to it.") {
            SettingsRow(
                "Connect Claude",
                detail: "Coming in the MCP milestone: Claude Code or Claude Desktop edits your deck, and every change "
                    + "shows up here to accept or undo."
            ) {
                Pill("Coming soon", .status(dot: CueTheme.violet))
            }
        }
    }
}
