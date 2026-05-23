import Foundation

/// A creepy "companion" that writes an escalating monologue into a Notes note,
/// as if the machine were typing to its user. Designed to run as part of a mode
/// (it sets the mood, then other pranks fire). Reversible: undo stops the timer
/// and removes the note.
///
/// The lines are a local scripted engine. `CompanionScript` is the extension
/// point where a local LLM could be plugged in later to generate replies — but
/// any such companion stays inside Loki's consent + reveal model (a mode always
/// ends with the RevealPrank; the global auto-reveal also applies).
public protocol CompanionScript {
    /// Return the next line given how many have been spoken so far.
    func nextLine(step: Int) -> String
}

/// Built-in escalating script with three moods.
struct ScriptedCompanion: CompanionScript {
    enum Tone: String { case playful, creepy, ominous }
    let tone: Tone
    let extra: [String]

    private static let playful = [
        "Hi 👋 Ich bin's, dein Computer.",
        "Mir ist langweilig. Spielen wir was?",
        "Du tippst heute aber langsam …",
        "Ich hab dein Hintergrundbild gesehen. Mutig.",
        "Pssst. Ich kann das hier lesen.",
    ]
    private static let creepy = [
        "Bist du allein?",
        "Ich beobachte den Cursor. Er zittert.",
        "Warum hast du aufgehört zu tippen?",
        "Ich war schon hier, bevor du kamst.",
        "Dreh dich nicht um.",
    ]
    private static let ominous = [
        "Ich übernehme jetzt.",
        "01001000 01001001",
        "Deine Dateien gehören jetzt mir.",
        "Drei … zwei … eins …",
        "Es ist zu spät, das zu schließen.",
    ]

    func nextLine(step: Int) -> String {
        var pool: [String]
        switch tone {
        case .playful: pool = Self.playful
        case .creepy: pool = Self.creepy
        case .ominous: pool = Self.ominous
        }
        pool += extra
        guard !pool.isEmpty else { return "…" }
        return pool[step % pool.count]
    }
}

public final class CompanionPrank: PrankModule {
    public let id = "companion"
    public let name = "Geist im System (Companion)"
    public let summary = "Schreibt einen eskalierenden, creepy Monolog in eine Notiz — wie ein Geist im Rechner."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = [.automation]
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("interval", "Intervall", min: 4, max: 120, step: 1, unit: "s", default: .double(12)),
            .choice("tone", "Stimmung", [
                .init("playful", "Verspielt"),
                .init("creepy", "Gruselig"),
                .init("ominous", "Bedrohlich"),
            ], default: .string("creepy")),
            .toggle("speak", "Auch vorlesen", default: .bool(false)),
            .list("extra", "Eigene Zeilen", placeholder: "Zeile 1, Zeile 2, …", default: .string("")),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.companion")
    private var step = 0
    private var lines: [String] = []
    private let noteTitle = "Loki"

    public init() {}

    public func run(context: PrankContext) throws {
        step = 0
        lines = []
        let interval = context.config.double(id, "interval", 12)
        timer.start(interval: interval, fireImmediately: true) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws {
        timer.stop()
        // Clean up the note so the prank is fully reversible.
        _ = try? context.runner.appleScript(
            "tell application \"Notes\"\nif (exists note \"\(noteTitle)\") then delete note \"\(noteTitle)\"\nend tell")
    }

    private func fire(context: PrankContext) {
        let toneRaw = context.config.string(id, "tone", "creepy")
        let tone = ScriptedCompanion.Tone(rawValue: toneRaw) ?? .creepy
        let extra = context.config.list(id, "extra", [])
        let script = ScriptedCompanion(tone: tone, extra: extra)

        let line = script.nextLine(step: step)
        step += 1
        lines.append(line)

        // Rebuild the note body. First line is the title so we can reference it.
        let body = ([noteTitle] + lines).map { $0.appleScriptEscaped }.joined(separator: "<br>")
        _ = try? context.runner.appleScript("""
        tell application "Notes"
        if (exists note "\(noteTitle)") then
        set body of note "\(noteTitle)" to "\(body)"
        else
        make new note with properties {body:"\(body)"}
        end if
        activate
        end tell
        """)

        if context.config.bool(id, "speak", false) {
            _ = try? context.runner.shell("/usr/bin/say", [line])
        }
    }
}
