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

/// A curated "flow" that orchestrates several pranks over time at a given
/// severity tier. Every mode MUST end with the reveal so the bit always
/// resolves — `ModeRunner` enforces this.
public struct PrankMode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let tier: Int          // 1 = mild, 2 = unsettling, 3 = full haunt
    public let steps: [ModeStep]

    public init(id: String, name: String, summary: String, tier: Int, steps: [ModeStep]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.tier = tier
        self.steps = steps
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

        // Guarantee a reveal at the very end, even if the mode forgot one.
        var steps = mode.steps
        let lastTime = steps.map(\.at).max() ?? 0
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
                summary: "Voller Flow: Der Companion meldet sich, dann eskaliert alles — endet mit Auflösung.",
                tier: 3,
                steps: [
                    ModeStep(at: 0, "companion"),
                    ModeStep(at: 25, "watcher"),
                    ModeStep(at: 50, "fakeNotifications"),
                    ModeStep(at: 75, "randomSounds"),
                    ModeStep(at: 95, "cursorJump"),
                    ModeStep(at: 115, "appearanceToggle"),
                    ModeStep(at: 140, "rickroll"),
                    ModeStep(at: 170, "fakeDialog"),
                    ModeStep(at: 195, "reveal"),
                ]
            ),
        ]
    }
}
