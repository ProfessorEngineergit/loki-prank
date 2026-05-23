import Foundation

/// A single configuration value for a prank. Stored primitively in UserDefaults.
public enum SettingValue: Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
}

/// Describes one tunable setting a prank exposes: how it's labelled, what
/// control renders it, its allowed range and its default. The UI builds itself
/// from these declarations, so adding a setting is purely declarative.
public struct PrankSetting: Sendable, Identifiable {
    public let key: String
    public let label: String
    public let help: String
    public let control: Control
    public let defaultValue: SettingValue

    public var id: String { key }

    public struct Choice: Sendable, Identifiable {
        public let id: String
        public let label: String
        public init(_ id: String, _ label: String) { self.id = id; self.label = label }
    }

    public enum Control: Sendable {
        case toggle
        case intStepper(min: Int, max: Int)
        case doubleSlider(min: Double, max: Double, step: Double, unit: String)
        case text(placeholder: String)
        case choice([Choice])
        /// Comma-separated editable list, stored as one string.
        case stringList(placeholder: String)
    }

    public init(_ key: String, _ label: String, help: String = "",
                control: Control, default defaultValue: SettingValue) {
        self.key = key
        self.label = label
        self.help = help
        self.control = control
        self.defaultValue = defaultValue
    }

    // Convenience builders for the common cases. `default` takes a SettingValue
    // (e.g. .bool(true), .int(5), .double(0.3), .string("x")).
    public static func toggle(_ key: String, _ label: String, help: String = "", default def: SettingValue) -> PrankSetting {
        .init(key, label, help: help, control: .toggle, default: def)
    }
    public static func intStepper(_ key: String, _ label: String, min: Int, max: Int, help: String = "", default def: SettingValue) -> PrankSetting {
        .init(key, label, help: help, control: .intStepper(min: min, max: max), default: def)
    }
    public static func slider(_ key: String, _ label: String, min: Double, max: Double, step: Double = 1, unit: String = "", help: String = "", default def: SettingValue) -> PrankSetting {
        .init(key, label, help: help, control: .doubleSlider(min: min, max: max, step: step, unit: unit), default: def)
    }
    public static func text(_ key: String, _ label: String, placeholder: String = "", help: String = "", default def: SettingValue) -> PrankSetting {
        .init(key, label, help: help, control: .text(placeholder: placeholder), default: def)
    }
    public static func list(_ key: String, _ label: String, placeholder: String = "", help: String = "", default def: SettingValue) -> PrankSetting {
        .init(key, label, help: help, control: .stringList(placeholder: placeholder), default: def)
    }
    public static func choice(_ key: String, _ label: String, _ choices: [Choice], help: String = "", default def: SettingValue) -> PrankSetting {
        .init(key, label, help: help, control: .choice(choices), default: def)
    }
}
