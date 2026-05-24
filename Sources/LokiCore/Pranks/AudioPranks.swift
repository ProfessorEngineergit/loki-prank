import Foundation

/// Randomly changes the output volume within a range. Reversible: undo stops
/// the timer and restores the original volume.
public final class VolumeChaosPrank: PrankModule {
    public let id = "volumeChaos"
    public let name = "Lautstärke-Chaos"
    public let summary = "Verstellt die Lautstärke in Abständen zufällig."
    public let category = PrankCategory.audio
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .intStepper("min", "Minimum", min: 0, max: 100, default: .int(0)),
            .intStepper("max", "Maximum", min: 0, max: 100, default: .int(100)),
            .slider("interval", "Intervall", min: 2, max: 120, step: 1, unit: "s", default: .double(8)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.volume")

    public init() {}

    public func run(context: PrankContext) throws {
        let original = (try? context.runner.appleScript("output volume of (get volume settings)")) ?? "50"
        context.store.saveOriginal("\(id).volume", value: original)
        let interval = context.config.double(id, "interval", 8)
        timer.start(interval: interval) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws {
        timer.stop()
        if let v = context.store.consumeOriginal("\(id).volume") {
            _ = try? context.runner.appleScript("set volume output volume \(v)")
        }
    }

    private func fire(context: PrankContext) {
        let lo = context.config.int(id, "min", 0)
        let hi = max(lo, context.config.int(id, "max", 100))
        let v = Int.random(in: lo...hi)
        _ = try? context.runner.appleScript("set volume output volume \(v)")
    }
}

/// Announces the current time at intervals, like an over-eager cuckoo clock.
/// Reversible: undo stops the timer.
public final class TalkingClockPrank: PrankModule {
    public let id = "talkingClock"
    public let name = "Sprechende Uhr"
    public let summary = "Sagt in Abständen die aktuelle Uhrzeit an."
    public let category = PrankCategory.audio
    public let intensity = Intensity.gentle
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("interval", "Intervall", min: 1, max: 60, step: 1, unit: " min", default: .double(15)),
            .text("voice", "Stimme", placeholder: "leer = Standard", default: .string("")),
            .text("template", "Ansage", help: "%@ wird durch die Uhrzeit ersetzt.",
                  default: .string("Es ist jetzt %@")),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.clock")

    public init() {}

    public func run(context: PrankContext) throws {
        let minutes = context.config.double(id, "interval", 15)
        timer.start(interval: minutes * 60, fireImmediately: true) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: Date())
        let template = context.config.string(id, "template", "Es ist jetzt %@")
        let phrase = template.replacingOccurrences(of: "%@", with: time)
        let voice = context.config.string(id, "voice", "")
        SpeechCenter.shared.say(phrase, voice: voice)
    }
}

/// Plays a random macOS system sound at intervals. Reversible: undo stops the timer.
public final class RandomSoundsPrank: PrankModule {
    public let id = "randomSounds"
    public let name = "Geister-Sounds"
    public let summary = "Spielt in Abständen zufällige System-Klänge ab."
    public let category = PrankCategory.audio
    public let intensity = Intensity.gentle
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("interval", "Intervall", min: 5, max: 300, step: 5, unit: "s", default: .double(30)),
        ]
    }

    private let soundsDir = "/System/Library/Sounds"
    private let timer = RepeatingTimer(label: "loki.sounds")

    public init() {}

    public func run(context: PrankContext) throws {
        let interval = context.config.double(id, "interval", 30)
        timer.start(interval: interval) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: soundsDir),
              let sound = files.filter({ $0.hasSuffix(".aiff") }).randomElement() else { return }
        _ = try? context.runner.shell("/usr/bin/afplay", ["\(soundsDir)/\(sound)"])
    }
}

/// Speaks aloud whatever the victim copies to the clipboard. Reversible: undo
/// stops the poller. Nothing is stored or transmitted — the text is only spoken.
public final class ClipboardSpeakerPrank: PrankModule {
    public let id = "clipboardSpeaker"
    public let name = "Sprechende Zwischenablage"
    public let summary = "Liest laut vor, was kopiert wird (wird nur gesprochen, nicht gespeichert)."
    public let category = PrankCategory.audio
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("interval", "Prüf-Intervall", min: 1, max: 10, step: 1, unit: "s", default: .double(2)),
            .intStepper("maxChars", "Max. Zeichen", min: 10, max: 500, default: .int(120)),
            .text("voice", "Stimme", placeholder: "leer = Standard", default: .string("")),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.clipboard")
    private var lastSeen = ""

    public init() {}

    public func run(context: PrankContext) throws {
        lastSeen = (try? context.runner.shell("/usr/bin/pbpaste", [])) ?? ""
        let interval = context.config.double(id, "interval", 2)
        timer.start(interval: interval) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        guard let current = try? context.runner.shell("/usr/bin/pbpaste", []),
              !current.isEmpty, current != lastSeen else { return }
        lastSeen = current
        let maxChars = context.config.int(id, "maxChars", 120)
        let text = String(current.prefix(maxChars))
        let voice = context.config.string(id, "voice", "")
        SpeechCenter.shared.say(text, voice: voice)
    }
}
