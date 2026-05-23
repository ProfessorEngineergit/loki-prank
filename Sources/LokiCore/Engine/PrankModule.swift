import Foundation

/// How alarming a prank looks to the victim. Drives UI grouping and lets the
/// operator filter by how far they want to go. Every prank, regardless of
/// intensity, must remain reversible and non-destructive.
public enum Intensity: Int, CaseIterable, Comparable, Sendable {
    case gentle = 0     // obviously a gag (a spoken phrase, a sound)
    case silly = 1      // annoying-funny (cursor jumps, screen flip)
    case hacky = 2      // looks serious but is fake (fake update / kernel panic)

    public static func < (lhs: Intensity, rhs: Intensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var label: String {
        switch self {
        case .gentle: return "Sanft"
        case .silly: return "Albern"
        case .hacky: return "Hack-Tier"
        }
    }
}

public enum PrankCategory: String, CaseIterable, Sendable {
    case browser = "Browser"
    case ui = "UI-Gremlins"
    case audio = "Audio & Stimme"
    case fakeSystem = "Fake-System"
    case input = "Tastatur & Maus"
}

/// macOS privacy permissions a prank needs before it can run.
public enum Permission: String, CaseIterable, Sendable {
    case automation = "Automatisierung (Apple Events)"
    case accessibility = "Bedienungshilfen"
    case screenRecording = "Bildschirmaufnahme"
}

/// A single prank. `run` performs the effect; `undo` reverses it.
///
/// Reversibility is the core safety contract: a prank that changes machine
/// state (wallpaper, volume, display rotation, …) MUST save the original via
/// the provided `StateStore` in `run` and restore it in `undo`. The
/// `PanicManager` relies on this to put everything back.
public protocol PrankModule: AnyObject {
    var id: String { get }
    var name: String { get }
    var summary: String { get }
    var category: PrankCategory { get }
    var intensity: Intensity { get }
    var requiredPermissions: [Permission] { get }

    /// True if the prank changes persistent state that `undo` must restore.
    /// One-shot pranks (a single spoken phrase) are not reversible and need no
    /// undo — they simply finish.
    var isReversible: Bool { get }

    /// Tunable settings this prank exposes. The UI renders controls from these
    /// declarations; pranks read current values via `context.config`.
    var settings: [PrankSetting] { get }

    /// Perform the prank. May start background work (timers/pollers) that keeps
    /// running until `undo` is called.
    func run(context: PrankContext) throws

    /// Reverse the prank and stop any background work. Must be idempotent:
    /// calling it twice, or on a prank that never ran, must be harmless.
    func undo(context: PrankContext) throws
}

public extension PrankModule {
    var summary: String { "" }
    var settings: [PrankSetting] { [] }
    func undo(context: PrankContext) throws {}
}

/// Shared services handed to every prank when it runs.
public final class PrankContext {
    public let runner: ScriptRunner
    public let store: StateStore
    public let config: ConfigStore

    public init(runner: ScriptRunner, store: StateStore, config: ConfigStore) {
        self.runner = runner
        self.store = store
        self.config = config
    }
}
