import Foundation

/// The "watcher": reacts in real time to what the user is doing — taunting them
/// for stopping, typing, switching apps, or (with vision on) for what's on
/// screen. Built for the highest tier / the haunt mode.
///
/// Lightweight and fully local (see `ScreenAwareness`): no data leaves the
/// machine, the keyboard signal is press-timing only (not a keylogger), and
/// vision is off by default. Reversible: undo stops the timer and the awareness.
public final class WatcherPrank: PrankModule {
    public let id = "watcher"
    public let name = "Der Beobachter (Vision)"
    public let summary = "Reagiert live auf dich: „Beweg dich nicht weg“, „Ich lese, was du tippst“ … Lokal & leichtgewichtig. Für das höchste Tier."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.hacky
    public var requiredPermissions: [Permission] { [.accessibility, .screenRecording] }
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("interval", "Reaktions-Intervall", min: 2, max: 20, step: 1, unit: "s", default: .double(4)),
            .toggle("keyboard", "Auf Tippen reagieren", help: "Erkennt nur, DASS getippt wird — nie welche Taste.", default: .bool(true)),
            .toggle("vision", "Lokale Bildschirm-Sicht (Vision)", help: "Liest ein paar Wörter on-device. Braucht Bildschirmaufnahme. Standard: aus.", default: .bool(false)),
            .toggle("speak", "Vorlesen", default: .bool(true)),
            .toggle("notify", "Als Mitteilung zeigen", default: .bool(true)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.watcher")
    private let awareness = ScreenAwareness()

    public init() {}

    public func run(context: PrankContext) throws {
        awareness.useKeyboard = context.config.bool(id, "keyboard", true)
        awareness.useVision = context.config.bool(id, "vision", false)
        awareness.start()
        let interval = context.config.double(id, "interval", 4)
        timer.start(interval: interval) { [weak self] in self?.react(context: context) }
    }

    public func undo(context: PrankContext) throws {
        timer.stop()
        awareness.stop()
    }

    private func react(context: PrankContext) {
        let snapshot = awareness.snapshot()
        guard let line = awareness.reactiveLine(snapshot) else { return }
        if context.config.bool(id, "notify", true) {
            _ = try? context.runner.appleScript(
                "display notification \"\(line.appleScriptEscaped)\" with title \"👁\"")
        }
        if context.config.bool(id, "speak", true) {
            _ = try? context.runner.shell("/usr/bin/say", [line])
        }
    }
}
