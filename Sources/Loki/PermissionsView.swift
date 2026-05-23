import SwiftUI
import LokiCore

/// Transparent permissions onboarding shown once after consent. Explains each
/// permission and lets the user grant them all up front via the normal system
/// prompts. Nothing here is covert — every row says what it's for.
struct PermissionsView: View {
    @EnvironmentObject var state: AppState
    // Bumped to re-read live permission status after a request.
    @State private var refresh = 0

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill").font(.system(size: 28)).foregroundStyle(Theme.accent)
                Text("Berechtigungen").font(.system(size: 20, weight: .bold))
                Text("Loki braucht diese Rechte, um Streiche auszuführen. Du kannst sie jederzeit in den Systemeinstellungen widerrufen.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Theme.brandGradient.opacity(0.12))

            VStack(spacing: 12) {
                row("gearshape.2.fill", "Automatisierung",
                    "Steuert Browser, Notes & Systemfunktionen (die meisten Streiche).",
                    granted: nil) { state.requestAutomation(); refresh += 1 }

                row("accessibility", "Bedienungshilfen",
                    "Maus-/Tastatursimulation für Maus-Drift & Co.",
                    granted: state.hasAccessibility) { state.requestAccessibility(); refresh += 1 }

                row("rectangle.dashed.badge.record", "Bildschirmaufnahme",
                    "Nur für „Bildschirm einfrieren“ (Screenshot als Hintergrund).",
                    granted: state.hasScreenRecording) { state.requestScreenRecording(); refresh += 1 }
            }
            .padding(16)
            .id(refresh)

            Spacer()

            VStack(spacing: 8) {
                Text("Manche Rechte verlangen, dass du Loki in den Systemeinstellungen aktivierst und die App neu startest.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button { state.acknowledgePermissions() } label: {
                    Text("Weiter zu Loki").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(20)
        }
    }

    private func row(_ icon: String, _ title: String, _ desc: String,
                     granted: Bool?, action: @escaping () -> Void) -> some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if granted == true {
                    Label("Erteilt", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly).foregroundStyle(Theme.accent2).font(.title3)
                } else {
                    Button("Erlauben", action: action)
                        .buttonStyle(PrimaryButtonStyle(color: Theme.accent))
                }
            }
        }
    }
}
