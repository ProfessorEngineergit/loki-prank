import SwiftUI

/// First-run gate. No prank can run until the operator accepts these terms.
struct ConsentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.brandGradient).frame(width: 64, height: 64)
                    Image(systemName: "theatermasks.fill").font(.system(size: 30)).foregroundStyle(.white)
                }
                Text("Willkommen bei Loki").font(.system(size: 22, weight: .bold))
                Text("Ein Werkzeug für einvernehmliche Streiche")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Theme.brandGradient.opacity(0.12))

            VStack(alignment: .leading, spacing: 16) {
                Text("Setze Loki **nur** auf Geräten ein, die dir gehören oder für die du die ausdrückliche Erlaubnis der besitzenden Person hast.")
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    rule("arrow.uturn.backward", "Alle Streiche sind reversibel und richten keinen Schaden an.", Theme.accent2)
                    rule("lock.shield.fill", "Kein Abgreifen von Passwörtern, Daten oder Tastatureingaben.", Theme.accent)
                    rule("clock.arrow.circlepath", "Auto-Auflösung & Panik-Taste (⌃⌥⌘P) stoppen alles und stellen den Zustand wieder her.", .orange)
                    rule("checkmark.seal.fill", "Jeder Modus endet mit „Das war Loki“ — der Streich löst sich immer auf.", Theme.accent2)
                }

                Text("Missbrauch — heimliche Überwachung oder Streiche ohne Einverständnis — ist nicht der Zweck dieses Tools und kann rechtswidrig sein.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button { state.accept() } label: {
                    Text("Ich verstehe und stimme zu").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
                .padding(.top, 4)
            }
            .padding(24)
            Spacer()
        }
    }

    private func rule(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 20)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}
