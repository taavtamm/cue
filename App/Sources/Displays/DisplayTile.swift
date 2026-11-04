import CueCore
import CueUI
import SwiftUI

/// One screen in the arrangement: what it shows, its name and resolution,
/// and a role badge.
struct DisplayTile: View {
    let display: DisplayInfo
    let role: DisplayRole
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                face
                caption
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(isSelected ? CueTheme.selection : Color.white.opacity(0.14),
                                        lineWidth: isSelected ? 3 : 1))
            .shadow(color: .black.opacity(0.5), radius: isSelected ? 25 : 18, y: isSelected ? 20 : 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(display.name), role \(role.title)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12, style: .continuous) }

    /// A dim, role-tinted screen with the role's symbol, so the arrangement
    /// reads at a glance without rendering the deck on every tile.
    private var face: some View {
        LinearGradient(
            colors: [role.color.opacity(role == .off ? 0.05 : 0.30), Color(white: 0.07)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: role.symbol)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.white.opacity(role == .off ? 0.25 : 0.7))
                .offset(y: -10)
        }
    }

    private var caption: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text(display.name).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                Text(display.resolutionText).font(.system(size: 10.5)).foregroundStyle(Color.white.opacity(0.72))
            }
            Spacer(minLength: 6)
            Pill(role.title, .badge(role.color))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))
    }
}
