import CueMCP
import Foundation

/// The tool calls the agent makes, passed to the Ask bar's status
/// (ClaudeConnection.activity): reading, looking, editing, listening.
extension MCPHostController {
    func toolDidStart(_ activity: ToolActivity) async {
        let entry = ClaudeActivity.Entry(activity)
        await MainActor.run { ClaudeConnection.shared.activity.started(entry) }
    }

    func toolDidFinish(_ activity: ToolActivity, failed: Bool) async {
        await MainActor.run { ClaudeConnection.shared.activity.finished(activity.id) }
    }
}

extension ClaudeActivity.Entry {
    init(_ activity: ToolActivity) {
        let kind: ClaudeActivity.Kind = switch activity.kind {
        case .reading: .reading
        case .rendering: .rendering
        case .editing: .editing
        case .waiting: .waiting
        }
        self.init(id: activity.id, client: activity.client, tool: activity.tool, kind: kind,
                  slide: activity.slide, detail: activity.detail)
    }
}
