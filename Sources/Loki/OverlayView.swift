import SwiftUI
import LokiCore

/// The hidden control panel, summoned by the global hotkey. Lists the catalog
/// grouped by category, lets the operator toggle pranks, and surfaces the panic
/// button prominently.
struct OverlayView: View {
    @EnvironmentObject var state: AppState
    @State private var expanded: Set<String> = []
    @State private var search = ""

    var body: some View {
        Group {
            if state.hasConsented {
                control
            } else {
                ConsentView()
            }
        }
    }

    private func matches(_ prank: PrankModule) -> Bool {
        guard !search.isEmpty else { return true }
        let q = search.lowercased()
        return prank.name.lowercased().contains(q) || prank.summary.lowercased().contains(q)
    }

    private var control: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(PrankCategory.allCases, id: \.self) { category in
                        let items = state.pranks.filter { $0.category == category && matches($0) }
                        if !items.isEmpty {
                            categorySection(category, items)
                        }
                    }
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 440, height: 600)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Streich suchen…", text: $search)
                .textFieldStyle(.plain)
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private var header: some View {
        HStack {
            Image(systemName: "theatermasks.fill")
            Text("Loki").font(.headline)
            Spacer()
            Button(role: .destructive) {
                state.panic()
            } label: {
                Label("PANIK", systemImage: "exclamationmark.octagon.fill")
            }
            .keyboardShortcut("p", modifiers: [.command, .option, .control])
        }
        .padding(12)
    }

    private func categorySection(_ category: PrankCategory, _ items: [PrankModule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue.uppercased())
                .font(.caption).bold().foregroundStyle(.secondary)
            ForEach(items, id: \.id) { prank in
                prankRow(prank)
            }
        }
    }

    private func prankRow(_ prank: PrankModule) -> some View {
        let active = state.isActive(prank)
        let isExpanded = expanded.contains(prank.id)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    state.toggle(prank)
                } label: {
                    Image(systemName: active ? "stop.circle.fill" : "play.circle")
                        .foregroundStyle(active ? .red : .accentColor)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(prank.name).bold()
                        intensityBadge(prank.intensity)
                        if active { Text("aktiv").font(.caption2).foregroundStyle(.red) }
                    }
                    if !prank.summary.isEmpty {
                        Text(prank.summary)
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()

                if !prank.settings.isEmpty {
                    Button {
                        if isExpanded { expanded.remove(prank.id) } else { expanded.insert(prank.id) }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(isExpanded ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Einstellungen")
                }
            }

            if isExpanded {
                PrankSettingsView(prank: prank)
            }
        }
    }

    private func intensityBadge(_ intensity: Intensity) -> some View {
        Text(intensity.label)
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(badgeColor(intensity).opacity(0.18), in: Capsule())
            .foregroundStyle(badgeColor(intensity))
    }

    private func badgeColor(_ intensity: Intensity) -> Color {
        switch intensity {
        case .gentle: return .green
        case .silly: return .orange
        case .hacky: return .red
        }
    }

    private var footer: some View {
        HStack {
            Text(state.lastStatus.isEmpty ? "Bereit" : state.lastStatus)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("Panik: ⌃⌥⌘P")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
    }
}
