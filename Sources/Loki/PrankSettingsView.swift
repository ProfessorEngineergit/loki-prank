import SwiftUI
import LokiCore

/// Renders the editable settings for one prank, building each control from the
/// prank's declarative `PrankSetting` list.
struct PrankSettingsView: View {
    @EnvironmentObject var state: AppState
    let prank: PrankModule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(prank.settings) { setting in
                control(for: setting)
            }
            HStack {
                Spacer()
                Button("Auf Standard zurücksetzen") { state.resetSettings(prank) }
                    .font(.caption)
                    .buttonStyle(.link)
            }
        }
        .padding(.leading, 4)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func control(for setting: PrankSetting) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            switch setting.control {
            case .toggle:
                Toggle(setting.label, isOn: state.boolBinding(prank, setting))
                    .font(.caption)

            case .intStepper(let min, let max):
                Stepper(value: state.intBinding(prank, setting), in: min...max) {
                    Text("\(setting.label): \(state.intBinding(prank, setting).wrappedValue)")
                        .font(.caption)
                }

            case .doubleSlider(let min, let max, let step, let unit):
                let binding = state.doubleBinding(prank, setting)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(setting.label): \(formatted(binding.wrappedValue))\(unit)")
                        .font(.caption)
                    Slider(value: binding, in: min...max, step: step)
                }

            case .text(let placeholder):
                VStack(alignment: .leading, spacing: 1) {
                    Text(setting.label).font(.caption)
                    TextField(placeholder, text: state.stringBinding(prank, setting), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .lineLimit(1...4)
                }

            case .stringList(let placeholder):
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(setting.label) (Komma-getrennt)").font(.caption)
                    TextField(placeholder, text: state.stringBinding(prank, setting), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .lineLimit(1...4)
                }

            case .choice(let choices):
                Picker(setting.label, selection: state.stringBinding(prank, setting)) {
                    ForEach(choices) { choice in
                        Text(choice.label).tag(choice.id)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
            }

            if !setting.help.isEmpty {
                Text(setting.help)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.2f", value)
    }
}
