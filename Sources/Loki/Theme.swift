import SwiftUI
import LokiCore

/// Shared visual language for Loki: trickster purple/green accents, soft cards,
/// tier and intensity colours.
enum Theme {
    static let accent = Color(red: 0.55, green: 0.36, blue: 0.96)   // Loki purple
    static let accent2 = Color(red: 0.30, green: 0.80, blue: 0.55)  // mischief green

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func intensityColor(_ i: Intensity) -> Color {
        switch i {
        case .gentle: return accent2
        case .silly:  return .orange
        case .hacky:  return Color(red: 0.95, green: 0.35, blue: 0.45)
        }
    }

    static func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return accent2
        case 2: return .orange
        default: return Color(red: 0.95, green: 0.35, blue: 0.45)
        }
    }

    static func categoryIcon(_ c: PrankCategory) -> String {
        switch c {
        case .browser:    return "globe"
        case .ui:         return "macwindow"
        case .audio:      return "speaker.wave.3.fill"
        case .input:      return "cursorarrow.rays"
        case .fakeSystem: return "exclamationmark.triangle.fill"
        }
    }
}

/// Rounded card container used throughout the UI.
struct Card<Content: View>: View {
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
    }
}

/// A small coloured capsule tag (intensity, tier, "aktiv").
struct Tag: View {
    let text: String
    let color: Color
    var filled: Bool = false
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(filled ? color : color.opacity(0.16),
                        in: Capsule())
            .foregroundStyle(filled ? .white : color)
    }
}

/// Prominent gradient action button (start / stop a mode).
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1),
                        in: Capsule())
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
