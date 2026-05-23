import Foundation

/// Posts fake system notifications at intervals. Reversible: undo stops the timer.
public final class FakeNotificationsPrank: PrankModule {
    public let id = "fakeNotifications"
    public let name = "Fake-Benachrichtigungen"
    public let summary = "Lässt in Abständen harmlose, aber verwirrende Mitteilungen aufpoppen."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    private static let defaultMessages = [
        "Ein Update wird heruntergeladen…",
        "Neues Gerät verbunden: Unbekannt",
        "Speicher fast voll",
        "iCloud konnte nicht synchronisieren",
        "Jemand hat sich in deinem Account angemeldet",
    ]

    public var settings: [PrankSetting] {
        [
            .text("title", "Titel", default: .string("Systemmitteilung")),
            .list("messages", "Mitteilungen", placeholder: "Text 1, Text 2, …",
                  default: .string(Self.defaultMessages.joined(separator: ", "))),
            .slider("interval", "Intervall", min: 5, max: 600, step: 5, unit: "s", default: .double(30)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.notify")

    public init() {}

    public func run(context: PrankContext) throws {
        let interval = context.config.double(id, "interval", 30)
        timer.start(interval: interval, fireImmediately: true) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        let title = context.config.string(id, "title", "Systemmitteilung")
        let messages = context.config.list(id, "messages", Self.defaultMessages)
        guard let msg = messages.randomElement() else { return }
        _ = try? context.runner.appleScript(
            "display notification \"\(msg.appleScriptEscaped)\" with title \"\(title.appleScriptEscaped)\"")
    }
}

/// Shows a fake (but real-looking) system dialog. It captures NO input — the
/// buttons do nothing but dismiss it. Optionally repeats on a timer.
public final class FakeDialogPrank: PrankModule {
    public let id = "fakeDialog"
    public let name = "Fake-Systemdialog"
    public let summary = "Zeigt einen täuschend echten, aber harmlosen Dialog (fragt nichts ab)."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .text("title", "Titel", default: .string("macOS")),
            .text("message", "Nachricht",
                  default: .string("Es ist ein unerwarteter Fehler aufgetreten. Bitte neu starten.")),
            .text("button", "Knopf-Text", default: .string("OK")),
            .choice("icon", "Symbol", [
                .init("note", "Info"),
                .init("caution", "Warnung"),
                .init("stop", "Stopp"),
            ], default: .string("caution")),
            .slider("interval", "Wiederholung", min: 0, max: 300, step: 5, unit: "s",
                    help: "0 = nur einmal.", default: .double(0)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.dialog")

    public init() {}

    public func run(context: PrankContext) throws {
        fire(context: context)
        let interval = context.config.double(id, "interval", 0)
        if interval > 0 {
            timer.start(interval: interval) { [weak self] in self?.fire(context: context) }
        }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        let title = context.config.string(id, "title", "macOS").appleScriptEscaped
        let message = context.config.string(id, "message", "").appleScriptEscaped
        let button = context.config.string(id, "button", "OK").appleScriptEscaped
        let icon = context.config.string(id, "icon", "caution")
        let script = "display dialog \"\(message)\" with title \"\(title)\" buttons {\"\(button)\"} default button 1 with icon \(icon)"
        _ = try? context.runner.appleScript(script)
    }
}

/// Opens Terminal and runs a harmless cinematic "hacking" sequence that prints
/// scary-looking text, then reveals it's a prank. Touches nothing real.
/// One-shot (not reversible — the Terminal window is left for the victim).
public final class HackerTerminalPrank: PrankModule {
    public let id = "hackerTerminal"
    public let name = "Hacker-Terminal"
    public let summary = "Öffnet ein Terminal mit kinoreifem Fake-Hacking — und löst sich dann als Streich auf."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = [.automation]
    public let isReversible = false

    public var settings: [PrankSetting] {
        [
            .text("reveal", "Auflösungs-Text",
                  default: .string("... nur ein Scherz. Liebe Grüße von Loki. :)")),
            .intStepper("lines", "Anzahl Zeilen", min: 5, max: 60, default: .int(20)),
        ]
    }

    private let scriptPath = "/tmp/loki_hack.sh"

    public init() {}

    public func run(context: PrankContext) throws {
        let reveal = context.config.string(id, "reveal", "... nur ein Scherz. Liebe Grüße von Loki. :)")
        let lines = context.config.int(id, "lines", 20)
        // Write a self-contained, harmless script (no real system commands).
        let script = """
        #!/bin/bash
        msgs=("ACCESSING MAINFRAME..." "BYPASSING FIREWALL..." "DECRYPTING 4096-BIT KEY..." \\
              "INJECTING PAYLOAD..." "ROOT ACCESS GRANTED" "DOWNLOADING SECRETS..." \\
              "ERASING TRACES..." "REROUTING THROUGH 7 PROXIES...")
        for i in $(seq 1 \(lines)); do
          m=${msgs[$((RANDOM % ${#msgs[@]}))]}
          printf "[%03d] %s\\n" "$i" "$m"
          sleep 0.2
        done
        echo
        echo "\(reveal.replacingOccurrences(of: "\"", with: "\\\""))"
        """
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        _ = try? context.runner.shell("/bin/chmod", ["+x", scriptPath])
        _ = try? context.runner.appleScript(
            "tell application \"Terminal\" to do script \"\(scriptPath)\"\ntell application \"Terminal\" to activate")
    }
}

/// Opens a text editor with a spooky message — as if the machine typed it
/// itself. One-shot (not reversible).
public final class GhostNotePrank: PrankModule {
    public let id = "ghostNote"
    public let name = "Geister-Notiz"
    public let summary = "Öffnet ein Textfenster mit einer geheimnisvollen Nachricht."
    public let category = PrankCategory.fakeSystem
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = [.automation]
    public let isReversible = false

    public var settings: [PrankSetting] {
        [
            .text("message", "Nachricht",
                  default: .string("Ich habe die Kontrolle übernommen.\n\nWiderstand ist zwecklos.\n\n– Loki")),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        let message = context.config.string(id, "message", "– Loki").appleScriptEscaped
        _ = try? context.runner.appleScript(
            "tell application \"TextEdit\"\nactivate\nmake new document with properties {text:\"\(message)\"}\nend tell")
    }
}
