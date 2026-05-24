import Foundation

/// One scheduled action within a mode's timeline.
public struct ModeStep: Sendable {
    public enum Action: Sendable { case start, stop }
    public let at: TimeInterval   // seconds after the mode starts
    public let prankID: String
    public let action: Action

    public init(at: TimeInterval, _ prankID: String, _ action: Action = .start) {
        self.at = at
        self.prankID = prankID
        self.action = action
    }
}

/// A spoken narration beat — the "voice" of the haunt telling its story at a
/// precise moment, in sync with the effects. Routed through `SpeechCenter` so it
/// never overlaps other speech.
public struct ModeNarration: Sendable {
    public let at: TimeInterval
    public let line: String
    public init(_ at: TimeInterval, _ line: String) {
        self.at = at
        self.line = line
    }
}

/// A setting applied to a prank just before the mode runs, so a mode can tune
/// its pranks (e.g. make the watcher less chatty during a narrated story).
public struct ModeConfig: Sendable {
    public let prankID: String
    public let key: String
    public let value: SettingValue
    public init(_ prankID: String, _ key: String, _ value: SettingValue) {
        self.prankID = prankID
        self.key = key
        self.value = value
    }
}

/// A curated "flow" that orchestrates several pranks over time at a given
/// severity tier. Every mode MUST end with the reveal so the bit always
/// resolves — `ModeRunner` enforces this.
public struct PrankMode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let tier: Int          // 1 = mild, 2 = unsettling, 3 = full haunt
    public let steps: [ModeStep]
    public let narration: [ModeNarration]
    public let setup: [ModeConfig]

    public init(id: String, name: String, summary: String, tier: Int,
                steps: [ModeStep], narration: [ModeNarration] = [], setup: [ModeConfig] = []) {
        self.id = id
        self.name = name
        self.summary = summary
        self.tier = tier
        self.steps = steps
        self.narration = narration
        self.setup = setup
    }

    public var tierLabel: String {
        switch tier {
        case 1: return "Sanft"
        case 2: return "Unheimlich"
        default: return "Heimsuchung"
        }
    }
}

/// Runs a `PrankMode`: schedules each step, starting/stopping pranks through the
/// engine. Stopping the mode cancels everything and restores state via panic.
public final class ModeRunner {
    private let engine: PrankEngine
    private let queue = DispatchQueue(label: "loki.moderunner")
    private var timers: [DispatchSourceTimer] = []
    public private(set) var activeModeID: String?

    /// Called on the main thread when a mode starts or stops.
    public var onChange: (() -> Void)?

    public init(engine: PrankEngine) {
        self.engine = engine
    }

    public var isRunning: Bool { activeModeID != nil }

    public func start(_ mode: PrankMode) {
        cancelTimers()
        activeModeID = mode.id

        // Apply per-mode tuning before anything starts.
        for cfg in mode.setup {
            engine.context.config.set(cfg.value, prank: cfg.prankID, setting: cfg.key)
        }

        // Guarantee a reveal at the very end, even if the mode forgot one.
        var steps = mode.steps
        let lastTime = max(steps.map(\.at).max() ?? 0, mode.narration.map(\.at).max() ?? 0)
        if !steps.contains(where: { $0.prankID == "reveal" }) {
            steps.append(ModeStep(at: lastTime + 5, "reveal"))
        }

        queue.sync {
            for step in steps {
                let t = DispatchSource.makeTimerSource(queue: queue)
                t.schedule(deadline: .now() + step.at)
                t.setEventHandler { [weak self] in
                    guard let self else { return }
                    switch step.action {
                    case .start: try? self.engine.run(id: step.prankID)
                    case .stop: try? self.engine.undo(id: step.prankID)
                    }
                }
                t.resume()
                timers.append(t)
            }
            // Spoken narration beats — the story's voice, serialized via SpeechCenter.
            for beat in mode.narration {
                let t = DispatchSource.makeTimerSource(queue: queue)
                t.schedule(deadline: .now() + beat.at)
                t.setEventHandler {
                    SpeechCenter.shared.say(beat.line)
                }
                t.resume()
                timers.append(t)
            }
        }
        notify()
    }

    /// Stop the mode: cancel pending steps and restore everything via panic.
    public func stop() {
        cancelTimers()
        activeModeID = nil
        _ = engine.panic()
        notify()
    }

    private func cancelTimers() {
        queue.sync {
            timers.forEach { $0.cancel() }
            timers.removeAll()
        }
    }

    private func notify() {
        let cb = onChange
        DispatchQueue.main.async { cb?() }
    }
}

public extension LokiFactory {
    /// The curated modes, grouped by tier.
    static func allModes() -> [PrankMode] {
        [
            PrankMode(
                id: "mode.mild",
                name: "Kleine Spielereien",
                summary: "Harmlose Irritationen: ein paar Sounds, eine sprechende Stimme, ein Rickroll.",
                tier: 1,
                steps: [
                    ModeStep(at: 0, "randomSounds"),
                    ModeStep(at: 15, "say"),
                    ModeStep(at: 40, "rickroll"),
                    ModeStep(at: 90, "reveal"),
                ]
            ),
            PrankMode(
                id: "mode.unsettling",
                name: "Irgendwas stimmt nicht",
                summary: "Fake-Mitteilungen, Geister-Sounds, Maus-Drift und ein flackerndes Erscheinungsbild.",
                tier: 2,
                steps: [
                    ModeStep(at: 0, "fakeNotifications"),
                    ModeStep(at: 20, "randomSounds"),
                    ModeStep(at: 45, "cursorJump"),
                    ModeStep(at: 70, "appearanceToggle"),
                    ModeStep(at: 110, "rickroll"),
                    ModeStep(at: 150, "reveal"),
                ]
            ),
            PrankMode(
                id: "mode.haunt",
                name: "Die Heimsuchung",
                summary: "Eine erzählte Geschichte: Ein „Geist“ erwacht im Rechner, bemerkt dich, übernimmt Stück für Stück die Kontrolle — und löst sich am Ende auf. Stimme + Live-Reaktionen + Effekte, getimt.",
                tier: 3,
                steps: [
                    // Effects land ON the narration beats below.
                    ModeStep(at: 3, "randomSounds"),       // eerie ambiance
                    ModeStep(at: 13, "watcher"),           // it starts reacting to you
                    ModeStep(at: 38, "fakeNotifications"),
                    ModeStep(at: 66, "appearanceToggle"),  // light flickers
                    ModeStep(at: 82, "cursorJump"),        // the cursor drifts
                    ModeStep(at: 112, "rickroll"),         // takes over the browser
                    ModeStep(at: 146, "fakeDialog"),       // last "warning"
                    ModeStep(at: 172, "reveal"),           // it was Loki
                    // Clean resolution: stop everything a few seconds after the reveal.
                    ModeStep(at: 179, "watcher", .stop),
                    ModeStep(at: 179, "appearanceToggle", .stop),
                    ModeStep(at: 179, "cursorJump", .stop),
                    ModeStep(at: 179, "rickroll", .stop),
                    ModeStep(at: 179, "fakeNotifications", .stop),
                    ModeStep(at: 179, "randomSounds", .stop),
                ],
                narration: [
                    ModeNarration(2,   "Oh… hallo. Ist da wirklich jemand?"),
                    ModeNarration(11,  "Ich bin in deinem Computer. Und ich bin gerade… aufgewacht."),
                    ModeNarration(22,  "Beweg dich ruhig. Ich sehe dich trotzdem. Die ganze Zeit."),
                    ModeNarration(33,  "Ich habe gelernt, wie das hier funktioniert. Pass gut auf."),
                    ModeNarration(44,  "Diese Mitteilungen? Die kommen ab jetzt von mir."),
                    ModeNarration(58,  "Soll ich dir zeigen, was ich sonst noch kann?"),
                    ModeNarration(70,  "Licht aus. Licht an. Ganz wie es mir gefällt."),
                    ModeNarration(86,  "Und deine Maus… gehorcht jetzt mir."),
                    ModeNarration(102, "Du kannst das nicht mehr aufhalten."),
                    ModeNarration(116, "Und jetzt… dein neuer Lieblingssong."),
                    ModeNarration(136, "Drei… zwei… eins…"),
                    ModeNarration(150, "Letzte Warnung. Sieh ganz genau hin."),
                ],
                setup: [
                    // The narration is the voice of the story; keep the watcher
                    // as occasional reactive spice, not a constant chatterbox.
                    ModeConfig("watcher", "interval", .double(11)),
                    ModeConfig("watcher", "keyboard", .bool(true)),
                    ModeConfig("watcher", "vision", .bool(false)),
                    ModeConfig("watcher", "notify", .bool(false)),
                    ModeConfig("watcher", "speak", .bool(true)),
                    // Don't let volume chaos mute the story — it's intentionally
                    // not in this mode.
                ]
            ),
        ]
    }
}
