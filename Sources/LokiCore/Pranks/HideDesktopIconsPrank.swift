import Foundation

/// Hides every icon on the desktop by flipping Finder's `CreateDesktop` flag.
/// Reversible: undo restores the original flag value and relaunches Finder.
public final class HideDesktopIconsPrank: PrankModule {
    public let id = "hideDesktopIcons"
    public let name = "Desktop-Icons verstecken"
    public let summary = "Lässt alle Symbole vom Schreibtisch verschwinden."
    public let category = PrankCategory.ui
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    private let stateKey = "hideDesktopIcons.createDesktop"

    public init() {}

    public func run(context: PrankContext) throws {
        // Capture the current value first (defaults exits non-zero if unset →
        // treat that as the macOS default of "true").
        let current = (try? context.runner.shell(
            "/usr/bin/defaults", ["read", "com.apple.finder", "CreateDesktop"]
        )) ?? "true"
        context.store.saveOriginal(stateKey, value: current)

        try context.runner.shell(
            "/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", "false"]
        )
        try context.runner.shell("/usr/bin/killall", ["Finder"])
    }

    public func undo(context: PrankContext) throws {
        let original = context.store.consumeOriginal(stateKey) ?? "true"
        let boolValue = (original == "1" || original.lowercased() == "true") ? "true" : "false"
        try context.runner.shell(
            "/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", boolValue]
        )
        try context.runner.shell("/usr/bin/killall", ["Finder"])
    }
}
