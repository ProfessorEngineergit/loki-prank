import Foundation

/// Persists per-prank settings in UserDefaults under the key
/// `loki.cfg.<prankID>.<settingKey>`. Pranks read their config with typed
/// getters that fall back to a supplied default, so a never-touched setting
/// just uses its declared default.
public final class ConfigStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ prank: String, _ setting: String) -> String {
        "loki.cfg.\(prank).\(setting)"
    }

    // MARK: Generic value access (used by the UI)

    public func value(prank: String, setting: PrankSetting) -> SettingValue {
        let k = key(prank, setting.key)
        guard defaults.object(forKey: k) != nil else { return setting.defaultValue }
        switch setting.defaultValue {
        case .bool: return .bool(defaults.bool(forKey: k))
        case .int: return .int(defaults.integer(forKey: k))
        case .double: return .double(defaults.double(forKey: k))
        case .string: return .string(defaults.string(forKey: k) ?? "")
        }
    }

    public func set(_ value: SettingValue, prank: String, setting: String) {
        let k = key(prank, setting)
        switch value {
        case .bool(let v): defaults.set(v, forKey: k)
        case .int(let v): defaults.set(v, forKey: k)
        case .double(let v): defaults.set(v, forKey: k)
        case .string(let v): defaults.set(v, forKey: k)
        }
    }

    // MARK: Typed getters used by pranks

    public func bool(_ prank: String, _ setting: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key(prank, setting)) == nil ? fallback : defaults.bool(forKey: key(prank, setting))
    }
    public func int(_ prank: String, _ setting: String, _ fallback: Int) -> Int {
        defaults.object(forKey: key(prank, setting)) == nil ? fallback : defaults.integer(forKey: key(prank, setting))
    }
    public func double(_ prank: String, _ setting: String, _ fallback: Double) -> Double {
        defaults.object(forKey: key(prank, setting)) == nil ? fallback : defaults.double(forKey: key(prank, setting))
    }
    public func string(_ prank: String, _ setting: String, _ fallback: String) -> String {
        defaults.string(forKey: key(prank, setting)) ?? fallback
    }
    /// A comma-separated list setting, split and trimmed into items.
    public func list(_ prank: String, _ setting: String, _ fallback: [String]) -> [String] {
        let raw = defaults.string(forKey: key(prank, setting))
        guard let raw, !raw.isEmpty else { return fallback }
        let items = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return items.isEmpty ? fallback : items
    }
}
