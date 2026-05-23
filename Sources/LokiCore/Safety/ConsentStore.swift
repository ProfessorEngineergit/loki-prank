import Foundation

/// Records that the operator accepted the consent terms (prank only devices you
/// own or have explicit permission for). The app refuses to run any prank until
/// this is accepted. Persisted so it's asked once per machine.
public final class ConsentStore {
    private let defaults: UserDefaults
    private let key = "loki.consentAccepted.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var hasConsented: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }

    private let permKey = "loki.permissionsAcknowledged.v1"

    /// Whether the user has been through the permissions onboarding once.
    public var permissionsAcknowledged: Bool {
        get { defaults.bool(forKey: permKey) }
        set { defaults.set(newValue, forKey: permKey) }
    }
}
