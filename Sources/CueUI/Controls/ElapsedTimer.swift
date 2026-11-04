import SwiftUI

/// The presenter's elapsed timer: big tabular numerals, the target time and
/// pace, and a thin progress bar. Formatting is in `ElapsedTimer.format`.
public struct ElapsedTimer: View {
    let elapsed: TimeInterval
    let target: TimeInterval?
    let pace: String?

    public init(elapsed: TimeInterval, target: TimeInterval? = nil, pace: String? = nil) {
        self.elapsed = elapsed
        self.target = target
        self.pace = pace
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Self.format(elapsed))
                .font(.system(size: 40, weight: .semibold))
                .tracking(-1)
                .monospacedDigit()
                .foregroundStyle(CueTheme.text)
            if let target {
                VStack(alignment: .leading, spacing: 5) {
                    Text(subtitle(target: target))
                        .font(.system(size: 12))
                        .foregroundStyle(CueTheme.textSecondary)
                    progress(fraction: min(elapsed / max(target, 1), 1))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Elapsed \(Self.format(elapsed))")
    }

    private func subtitle(target: TimeInterval) -> String {
        ["of \(Self.format(target))", pace].compactMap(\.self).joined(separator: " · ")
    }

    private func progress(fraction: Double) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.12))
            .frame(width: 120, height: 4)
            .overlay(alignment: .leading) {
                Capsule().fill(CueTheme.successBright).frame(width: 120 * fraction, height: 4)
            }
    }

    /// "12:48", or "1:02:05" past an hour.
    public nonisolated static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    ElapsedTimer(elapsed: 768, target: 1500, pace: "on pace").padding(24).background(CueTheme.ground)
}
