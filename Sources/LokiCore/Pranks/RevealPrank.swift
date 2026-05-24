import Foundation

/// The reveal. Shows a friendly, unmistakable "it was a prank" message. Every
/// mode ends with this so the bit always resolves — that's what keeps Loki a
/// prank and not harassment. One-shot (not reversible).
public final class RevealPrank: PrankModule {
    public let id = "reveal"
    public let name = "Auflösung"
    public let summary = "Zeigt freundlich, dass alles nur ein Loki-Streich war."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.gentle
    public let requiredPermissions: [Permission] = []
    public let isReversible = false

    public var settings: [PrankSetting] {
        [
            .text("message", "Auflösungs-Text",
                  default: .string("🎭 Das war alles nur Loki!\n\nKeine Sorge — nichts wurde beschädigt, alles wird zurückgesetzt. Hab dich lieb. 💚")),
            .toggle("speak", "Auch vorlesen", default: .bool(true)),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        let message = context.config.string(id, "message",
            "🎭 Das war alles nur Loki!")
        // Interrupt any ongoing haunt speech — the reveal cuts through everything.
        if context.config.bool(id, "speak", true) {
            SpeechCenter.shared.say("Überraschung! Das war nur Loki.", interrupt: true)
        }
        _ = try? context.runner.appleScript(
            "display dialog \"\(message.appleScriptEscaped)\" with title \"Loki\" buttons {\"Haha 😄\"} default button 1 with icon note")
    }
}
