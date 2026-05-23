import SwiftUI
import LokiCore

/// Root of the overlay. Routes through onboarding (consent → permissions) into
/// the main shell.
struct OverlayView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            if !state.hasConsented {
                ConsentView()
            } else if !state.permissionsAcknowledged {
                PermissionsView()
            } else {
                MainShell()
            }
        }
        .frame(width: 480, height: 680)
        .background(BackdropView())
    }
}

/// Subtle dark gradient backdrop behind the whole UI.
private struct BackdropView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            LinearGradient(
                colors: [Theme.accent.opacity(0.12), .clear, Theme.accent2.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Main shell

private enum Tab: String, CaseIterable { case modes = "Modi", pranks = "Streiche" }

struct MainShell: View {
    @EnvironmentObject var state: AppState
    @State private var tab: Tab = .modes

    var body: some View {
        VStack(spacing: 0) {
            brandHeader
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().opacity(0.4)

            ScrollView {
                Group {
                    switch tab {
                    case .modes:  ModesView()
                    case .pranks: PranksView()
                    }
                }
                .padding(16)
            }

            controlBar
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.brandGradient).frame(width: 40, height: 40)
                Image(systemName: "theatermasks.fill")
                    .foregroundStyle(.white).font(.system(size: 19))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Loki").font(.system(size: 22, weight: .bold))
                Text("Streiche, die zusammenspielen")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)
    }

    private var controlBar: some View {
        VStack(spacing: 8) {
            Divider().opacity(0.4)
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(.secondary).font(.caption)
                Stepper(value: $state.autoRevealMinutes, in: 0...120, step: 1) {
                    Text(state.autoRevealMinutes <= 0
                         ? "Auto-Auflösung: aus"
                         : "Auto-Auflösung: \(Int(state.autoRevealMinutes)) min")
                        .font(.caption)
                }
                .help("Nach dem Start eines Streichs poppt automatisch „Das war Loki“ auf und alles wird zurückgesetzt.")
                Spacer()
                Button(role: .destructive) { state.panic(); state.stopMode() } label: {
                    Label("PANIK", systemImage: "exclamationmark.octagon.fill")
                }
                .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.95, green: 0.35, blue: 0.45)))
                .keyboardShortcut("p", modifiers: [.command, .option, .control])
            }
            Text(state.lastStatus.isEmpty ? "Bereit · Panik: ⌃⌥⌘P" : state.lastStatus)
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
