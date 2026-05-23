import SwiftUI

/// First-run gate. No prank can run until the operator accepts these terms.
struct ConsentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Loki — Einverständnis")
                .font(.title2).bold()

            Text("Loki ist ein Werkzeug für einvernehmliche Streiche. Setze es **nur** auf Geräten ein, die dir gehören oder für die du die ausdrückliche Erlaubnis der besitzenden Person hast.")
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Label("Alle Streiche sind reversibel und richten keinen Schaden an.", systemImage: "arrow.uturn.backward")
                Label("Kein Abgreifen von Passwörtern, Daten oder Tastatureingaben.", systemImage: "lock.shield")
                Label("Panik-Taste (⌃⌥⌘P) stoppt alles und stellt den Zustand wieder her.", systemImage: "exclamationmark.octagon")
            }
            .font(.callout)

            Text("Missbrauch — etwa heimliche Überwachung oder Streiche ohne Einverständnis — ist nicht der Zweck dieses Tools und kann rechtswidrig sein.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Ich verstehe und stimme zu") { state.accept() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
