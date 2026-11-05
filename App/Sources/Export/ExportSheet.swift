import CueExport
import CueUI
import SwiftUI

/// File › Export…: pick PowerPoint, PDF or images, then watch it go.
struct ExportSheet: View {
    @Bindable var model: ExportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export “\(model.deckName)”").font(.system(size: 15, weight: .semibold))
            HStack(spacing: 10) {
                ForEach(DeckExport.Format.allCases, id: \.self) { format in
                    formatCard(format)
                }
            }
            if model.format == .images {
                SegmentedSwitch(selection: $model.imageScale, options: [1.0, 2.0]) { $0 == 1 ? "1× (1920 px)" : "2× (3840 px)" }
                    .fixedSize()
            }
            Text(note).font(.system(size: 11.5)).foregroundStyle(CueTheme.textTertiary).fixedSize(horizontal: false, vertical: true)
            if let progress = model.progress {
                ProgressView(value: progress).tint(CueTheme.selection)
                Text(model.status).font(.system(size: 11.5)).foregroundStyle(CueTheme.textSecondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.cancel() }.buttonStyle(.cue(height: 30))
                Button("Export…") { model.export() }.buttonStyle(.cue(.primary, height: 30))
                    .disabled(model.isRunning)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
        .foregroundStyle(CueTheme.text)
        .background(CueBackground())
    }

    private func formatCard(_ format: DeckExport.Format) -> some View {
        let selected = model.format == format
        return Button { model.format = format } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon(format)).font(.system(size: 20))
                Text(title(format)).font(.system(size: 13, weight: .semibold))
                Text(subtitle(format)).font(.system(size: 11)).foregroundStyle(CueTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(12)
            .background(selected ? CueTheme.selection.opacity(0.16) : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? CueTheme.selection.opacity(0.6) : Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .disabled(model.isRunning)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func icon(_ format: DeckExport.Format) -> String {
        switch format {
        case .powerPoint: "rectangle.stack"
        case .pdf: "doc.richtext"
        case .images: "photo.on.rectangle"
        }
    }

    private func title(_ format: DeckExport.Format) -> String {
        switch format {
        case .powerPoint: "PowerPoint"
        case .pdf: "PDF"
        case .images: "Images"
        }
    }

    private func subtitle(_ format: DeckExport.Format) -> String {
        switch format {
        case .powerPoint: "Editable text and pictures"
        case .pdf: "One page per slide"
        case .images: "One PNG per slide"
        }
    }

    private var note: String {
        switch model.format {
        case .powerPoint:
            "Text and pictures stay editable. Everything else on a slide (shapes, backgrounds, live embeds) "
                + "becomes one picture behind them. Animations and builds are shown finished. Notes come along."
        case .pdf: "Each slide in its final build state. Text stays selectable."
        case .images: "Each slide in its final build state, into a folder."
        }
    }
}
