import Foundation

/// A talking companion: a creepy "ghost in the machine" that speaks to the user
/// out loud (no Notes). It can run on a built-in scripted brain or — fully
/// locally — on Ollama, and it can optionally listen and answer back via voice.
///
/// Everything stays on the machine: speech is local (`say`), recognition is
/// on-device (`VoiceListener`), and the LLM is a local Ollama server. Like all
/// of Loki, it lives inside the consent + reveal model (the haunt mode and the
/// global auto-reveal both resolve it).
public final class CompanionPrank: PrankModule {
    public let id = "companion"
    public let name = "Sprechender Companion (KI)"
    public let summary = "Spricht mit dir — eskalierend & creepy. Optional mit lokalem LLM (Ollama) und gesprochener Antwort. Kein Notes, alles lokal."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = [.microphone, .speechRecognition]
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("interval", "Spricht alle", min: 5, max: 120, step: 1, unit: "s", default: .double(14)),
            .choice("tone", "Stimmung", [
                .init("playful", "Verspielt"),
                .init("creepy", "Gruselig"),
                .init("ominous", "Bedrohlich"),
            ], default: .string("creepy")),
            .toggle("listen", "Auf gesprochene Antworten reagieren",
                    help: "Du redest, er antwortet. On-device, braucht Mikrofon + Spracherkennung.", default: .bool(false)),
            .toggle("useLLM", "Lokales LLM (Ollama)",
                    help: "Echte Antworten über ein lokales Ollama. Wenn nicht erreichbar, nutzt er die eingebauten Sätze.", default: .bool(false)),
            .text("model", "LLM-Modell", placeholder: "z. B. llama3.2", default: .string("llama3.2")),
            .text("voice", "Stimme", placeholder: "leer = Standard", default: .string("")),
            .list("extra", "Eigene Sätze", placeholder: "Satz 1, Satz 2, …", default: .string("")),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.companion")
    private let work = DispatchQueue(label: "loki.companion.brain")
    private let listener = VoiceListener()
    private var history: [String] = []
    private var brain: CompanionBrain = ScriptedBrain()
    private var tone = "creepy"
    private var voice = ""

    public init() {}

    public func run(context: PrankContext) throws {
        history = []
        tone = context.config.string(id, "tone", "creepy")
        voice = context.config.string(id, "voice", "")
        let extra = context.config.list(id, "extra", [])

        if context.config.bool(id, "useLLM", false) {
            let model = context.config.string(id, "model", "llama3.2")
            let llm = LocalLLMBrain(model: model)
            brain = FallbackBrain(primary: llm, backup: ScriptedBrain(extra: extra))
        } else {
            brain = ScriptedBrain(extra: extra)
        }

        // Optional: let the user talk back.
        if context.config.bool(id, "listen", false) {
            listener.onTranscript = { [weak self] text in
                self?.handleUserSpoke(text, context: context)
            }
            DispatchQueue.main.async { [weak self] in
                VoiceListener.requestAuthorization { granted in
                    guard granted else { return }
                    self?.listener.start()
                    self?.speak("Du kannst mit mir reden. Sag einfach etwas.", context: context)
                }
            }
        }

        let interval = context.config.double(id, "interval", 14)
        timer.start(interval: interval, fireImmediately: true) { [weak self] in
            self?.monologue(context: context)
        }
    }

    public func undo(context: PrankContext) throws {
        timer.stop()
        listener.stop()
        history = []
    }

    private func monologue(context: PrankContext) {
        let line = brain.reply(to: nil, history: history, tone: tone) ?? "…"
        speak(line, context: context)
    }

    private func handleUserSpoke(_ text: String, context: PrankContext) {
        history.append("Du: \(text)")
        work.async { [weak self] in
            guard let self else { return }
            let reply = self.brain.reply(to: text, history: self.history, tone: self.tone) ?? "Ich habe dich gehört."
            self.speak(reply, context: context)
        }
    }

    private func speak(_ line: String, context: PrankContext) {
        history.append(line)
        if history.count > 40 { history.removeFirst(history.count - 40) }
        var args: [String] = []
        if !voice.isEmpty { args += ["-v", voice] }
        args.append(line)
        _ = try? context.runner.shell("/usr/bin/say", args)
    }
}

/// Uses the primary brain (e.g. local LLM); if it returns nil (server down),
/// falls back to the scripted brain so the companion always says something.
struct FallbackBrain: CompanionBrain {
    let primary: CompanionBrain
    let backup: CompanionBrain
    func reply(to userText: String?, history: [String], tone: String) -> String? {
        primary.reply(to: userText, history: history, tone: tone)
            ?? backup.reply(to: userText, history: history, tone: tone)
    }
}
