import SwiftUI
import LokiCore

/// The full prank catalog: searchable, grouped by category, each prank a card
/// with an expandable settings panel.
struct PranksView: View {
    @EnvironmentObject var state: AppState
    @State private var expanded: Set<String> = []
    @State private var search = ""

    private func matches(_ p: PrankModule) -> Bool {
        guard !search.isEmpty else { return true }
        let q = search.lowercased()
        return p.name.lowercased().contains(q) || p.summary.lowercased().contains(q)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            searchField
            ForEach(PrankCategory.allCases, id: \.self) { category in
                let items = state.pranks.filter { $0.category == category && matches($0) }
                if !items.isEmpty {
                    categorySection(category, items)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Streich suchen…", text: $search)
                .textFieldStyle(.plain)
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }

    private func categorySection(_ category: PrankCategory, _ items: [PrankModule]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: Theme.categoryIcon(category)).font(.caption)
                Text(category.rawValue.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.5)
            }
            .foregroundStyle(.secondary)

            ForEach(items, id: \.id) { prank in
                prankCard(prank)
            }
        }
    }

    private func prankCard(_ prank: PrankModule) -> some View {
        let active = state.isActive(prank)
        let isExpanded = expanded.contains(prank.id)
        let color = Theme.intensityColor(prank.intensity)
        return Card(padding: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Button { state.toggle(prank) } label: {
                        ZStack {
                            Circle().fill(active ? color : color.opacity(0.16)).frame(width: 30, height: 30)
                            Image(systemName: active ? "stop.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(active ? .white : color)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(prank.name).font(.system(size: 13, weight: .semibold))
                            Tag(text: prank.intensity.label, color: color)
                            if active { Tag(text: "aktiv", color: color, filled: true) }
                        }
                        if !prank.summary.isEmpty {
                            Text(prank.summary).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 4)

                    if !prank.settings.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if isExpanded { expanded.remove(prank.id) } else { expanded.insert(prank.id) }
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(isExpanded ? Theme.accent : .secondary)
                                .padding(6)
                                .background(isExpanded ? Theme.accent.opacity(0.14) : .clear, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Einstellungen")
                    }
                }

                if isExpanded {
                    Divider().opacity(0.4)
                    PrankSettingsView(prank: prank)
                }
            }
        }
    }
}
