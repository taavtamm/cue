import AppKit
import CueCore
import CueEditor
import CueUI
import SwiftUI

/// Font family and weight for the selected text. Fonts the deck already uses
/// come first, then the fonts installed on this Mac. "All like this" writes
/// the change to Cue's override block for every element with the same class.
struct FontPicker: View {
    let session: EditorSession
    let values: InspectorValues

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Section("In this deck") {
                    ForEach(Self.deckFamilies(in: session.document.source), id: \.self) { family in
                        Button(family) { set("font-family", ElementTemplateCSS.family(family)) }
                    }
                }
                Section("On this Mac") {
                    ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                        Button(family) { set("font-family", ElementTemplateCSS.family(family)) }
                    }
                }
            } label: {
                Text(values.fontFamily.isEmpty ? "—" : values.fontFamily).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(.button)
            Menu {
                ForEach(Self.weights, id: \.0) { weight, name in
                    Button(name) { set("font-weight", weight) }
                }
            } label: {
                Text(values.fontWeight).foregroundStyle(CueTheme.textTertiary)
            }
            .menuStyle(.button)
            .fixedSize()
            if let className = firstClass {
                Menu {
                    Button("Use \(values.fontFamily) for all .\(className)") {
                        override(".\(className)", "font-family", ElementTemplateCSS.family(values.fontFamily))
                    }
                    Button("Use \(values.fontSize) px for all .\(className)") {
                        override(".\(className)", "font-size", values.fontSize + "px")
                    }
                } label: {
                    Image(systemName: "square.stack.3d.up")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Apply to all like this")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    private var firstClass: String? {
        session.selection?.element.attributes["class"]?.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    private func set(_ property: String, _ value: String) {
        guard let path = session.selection?.path else { return }
        Task { await session.apply(.setStyle(path, property: property, value: value)) }
    }

    private func override(_ selector: String, _ property: String, _ value: String) {
        Task { await session.apply(.setOverride(selector: selector, property: property, value: value)) }
    }

    static let weights: [(String, String)] = [
        ("300", "Light"), ("400", "Regular"), ("500", "Medium"), ("600", "Semibold"), ("700", "Bold"), ("800", "Heavy"),
    ]

    /// First family named in each `font-family` the deck declares.
    static func deckFamilies(in source: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"font-family\s*:\s*([^;}"]+)"#) else { return [] }
        var seen: [String] = []
        let range = NSRange(source.startIndex..., in: source)
        for match in regex.matches(in: source, range: range).prefix(400) {
            guard let value = Range(match.range(at: 1), in: source).map({ String(source[$0]) }) else { continue }
            let first = InspectorFamily.first(value)
            if !first.isEmpty, !first.hasPrefix("var("), !seen.contains(first) { seen.append(first) }
            if seen.count >= 12 { break }
        }
        return seen
    }
}

/// Quoting a family name for CSS.
enum ElementTemplateCSS {
    static func family(_ name: String) -> String {
        name.contains(" ") ? "'\(name.replacingOccurrences(of: "'", with: ""))'" : name
    }
}

/// The first family in a CSS `font-family` list, unquoted.
enum InspectorFamily {
    static func first(_ list: String) -> String {
        let first = list.split(separator: ",").first.map(String.init) ?? list
        return first.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"'")))
    }
}
