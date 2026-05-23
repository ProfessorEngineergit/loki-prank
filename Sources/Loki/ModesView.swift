import SwiftUI
import LokiCore

/// Shows the curated modes as tier cards. Starting a mode runs an orchestrated
/// flow of pranks that always ends with the reveal.
struct ModesView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Orchestrierte Abläufe — mehrere Streiche, die nacheinander zusammenspielen und sich am Ende selbst auflösen.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(state.modes) { mode in
                modeCard(mode)
            }

            Label("Jeder Modus endet mit „Das war Loki“ und setzt alles zurück.",
                  systemImage: "checkmark.seal.fill")
                .font(.caption2).foregroundStyle(Theme.accent2)
                .padding(.top, 4)
        }
    }

    private func modeCard(_ mode: PrankMode) -> some View {
        let active = state.isModeActive(mode)
        let color = Theme.tierColor(mode.tier)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(color.opacity(0.18)).frame(width: 34, height: 34)
                        Text("\(mode.tier)").font(.headline).foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(mode.name).font(.system(size: 15, weight: .semibold))
                            Tag(text: mode.tierLabel, color: color)
                            if active { Tag(text: "läuft", color: color, filled: true) }
                        }
                        Text("\(mode.steps.count) Schritte")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text(mode.summary)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Spacer()
                    if active {
                        Button { state.stopMode() } label: {
                            Label("Stoppen & zurücksetzen", systemImage: "stop.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.95, green: 0.35, blue: 0.45)))
                    } else {
                        Button { state.startMode(mode) } label: {
                            Label("Starten", systemImage: "play.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle(color: color))
                        .disabled(state.activeModeID != nil)
                    }
                }
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4)
                .padding(.vertical, 8)
        }
    }
}
