import Foundation

/// Periodically speaks a random phrase through the system voice. One-shot when
/// run once; as a recurring gag it starts a timer, so it is reversible (undo
/// stops the timer). Purely a gag — nothing is changed on the machine.
public final class SayPrank: PrankModule {
    public let id = "say"
    public let name = "Zufällige Sprachausgabe"
    public let summary = "Der Mac spricht in zufälligen Abständen einen mysteriösen Satz."
    public let category = PrankCategory.audio
    public let intensity = Intensity.gentle
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    private static let defaultPhrases = [
        "Ich sehe dich.",
        "Hast du das auch gehört?",
        "Bitte berühre die Tastatur nicht.",
        "Ein neues Update ist verfügbar.",
        "Hallo? Ist da jemand?",
        "Deine Dateien sind in Sicherheit. Vorerst.",
    ]

    public var settings: [PrankSetting] {
        [
            .list("phrases", "Sätze", placeholder: "Satz 1, Satz 2, …",
                  help: "Komma-getrennt. Ein zufälliger Satz wird gesprochen.",
                  default: .string(Self.defaultPhrases.joined(separator: ", "))),
            .slider("interval", "Intervall", min: 5, max: 600, step: 5, unit: "s",
                    help: "Abstand zwischen den Sätzen.", default: .double(45)),
            .text("voice", "Stimme", placeholder: "z. B. Anna (leer = Standard)",
                  help: "Name einer installierten Stimme (`say -v ?`).", default: .string("")),
            .slider("rate", "Sprechtempo", min: 100, max: 400, step: 10, unit: " WpM",
                    help: "Wörter pro Minute.", default: .double(180)),
        ]
    }

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "loki.say")

    public init() {}

    public func run(context: PrankContext) throws {
        let interval = context.config.double(id, "interval", 45)
        queue.sync {
            timer?.cancel()
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + interval, repeating: interval)
            t.setEventHandler { [weak self] in
                self?.speak(context: context)
            }
            t.resume()
            timer = t
        }
        speak(context: context)
    }

    public func undo(context: PrankContext) throws {
        queue.sync {
            timer?.cancel()
            timer = nil
        }
    }

    private func speak(context: PrankContext) {
        let phrases = context.config.list(id, "phrases", Self.defaultPhrases)
        guard let phrase = phrases.randomElement() else { return }
        let voice = context.config.string(id, "voice", "")
        let rate = Int(context.config.double(id, "rate", 180))
        SpeechCenter.shared.say(phrase, voice: voice, rate: rate)
    }
}
