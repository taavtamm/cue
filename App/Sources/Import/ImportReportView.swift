import CueImport
import CueUI
import SwiftUI

/// What an import couldn't carry across exactly, shown after the deck opens.
struct ImportReportView: View {
    let report: ImportReport
    let onGetKeynote: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.on.square").foregroundStyle(CueTheme.liveText)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Imported “\(report.sourceName)”").font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 11.5)).foregroundStyle(CueTheme.textSecondary)
                }
                Spacer(minLength: 8)
                if let onGetKeynote {
                    Button("Get Keynote", action: onGetKeynote).buttonStyle(.cue(.primary, height: 30))
                }
                Button("Done", action: onDismiss).buttonStyle(.cue(.glass, height: 30))
            }
            if !report.summaryLines.isEmpty {
                SectionLabel("Not carried across exactly")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(report.summaryLines.prefix(8), id: \.self) { line in
                        Text("• " + line).font(.system(size: 12)).foregroundStyle(CueTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if report.summaryLines.count > 8 {
                        Text("and \(report.summaryLines.count - 8) more").font(.system(size: 12))
                            .foregroundStyle(CueTheme.textTertiary)
                    }
                }
            }
        }
        .foregroundStyle(CueTheme.text)
        .padding(16)
        .cueGlass(.panel)
    }

    private var subtitle: String {
        var parts = ["via \(report.route)"]
        if report.isPresentOnly { parts.append("present-only: slides are pictures, notes can be edited") }
        if let folder = report.outputRelocated { parts.append("saved in \(folder.lastPathComponent), the original's folder is read-only") }
        if report.summaryLines.isEmpty { parts.append("everything came across") }
        return parts.joined(separator: " · ")
    }
}
