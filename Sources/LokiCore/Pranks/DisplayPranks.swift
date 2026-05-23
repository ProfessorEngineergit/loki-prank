import Foundation

/// Inverts the display colours via the system accessibility shortcut
/// (⌃⌥⌘8). Requires that shortcut to be enabled and Accessibility permission.
/// Reversible: undo toggles back.
public final class InvertColorsPrank: PrankModule {
    public let id = "invertColors"
    public let name = "Farben invertieren"
    public let summary = "Dreht die Bildschirmfarben um (benötigt aktivierten Kurzbefehl ⌃⌥⌘8)."
    public let category = PrankCategory.ui
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = [.accessibility]
    public let isReversible = true

    public init() {}

    private func toggle(context: PrankContext) {
        // key code 28 == "8"
        _ = try? context.runner.appleScript(
            "tell application \"System Events\" to key code 28 using {control down, option down, command down}")
    }

    public func run(context: PrankContext) throws { toggle(context: context) }
    public func undo(context: PrankContext) throws { toggle(context: context) }
}

/// The classic "frozen desktop": screenshot the screen, set it as the wallpaper
/// and hide the real icons (and optionally the Dock), so clicking does nothing.
/// Reversible: undo restores wallpaper, icons and Dock.
public final class WallpaperFreezePrank: PrankModule {
    public let id = "wallpaperFreeze"
    public let name = "Bildschirm einfrieren"
    public let summary = "Macht ein Foto des Schreibtischs und legt es als Hintergrund an — der Mac wirkt eingefroren."
    public let category = PrankCategory.ui
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = [.screenRecording]
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .toggle("hideIcons", "Icons verstecken", default: .bool(true)),
            .toggle("hideDock", "Dock ausblenden", default: .bool(true)),
        ]
    }

    private let snapshot = "/tmp/loki_freeze.png"

    public init() {}

    public func run(context: PrankContext) throws {
        // Save originals.
        let wp = (try? context.runner.appleScript(
            "tell application \"System Events\" to get picture of current desktop")) ?? ""
        context.store.saveOriginal("\(id).wallpaper", value: wp)

        try context.runner.shell("/usr/sbin/screencapture", ["-x", snapshot])
        _ = try? context.runner.appleScript(
            "tell application \"System Events\" to set picture of every desktop to \"\(snapshot)\"")

        if context.config.bool(id, "hideIcons", true) {
            let cur = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.finder", "CreateDesktop"])) ?? "true"
            context.store.saveOriginal("\(id).icons", value: cur)
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", "false"])
            _ = try? context.runner.shell("/usr/bin/killall", ["Finder"])
        }
        if context.config.bool(id, "hideDock", true) {
            let cur = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.dock", "autohide"])) ?? "0"
            context.store.saveOriginal("\(id).dock", value: cur)
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", "true"])
            _ = try? context.runner.shell("/usr/bin/killall", ["Dock"])
        }
    }

    public func undo(context: PrankContext) throws {
        if let wp = context.store.consumeOriginal("\(id).wallpaper"), !wp.isEmpty {
            _ = try? context.runner.appleScript(
                "tell application \"System Events\" to set picture of every desktop to \"\(wp)\"")
        }
        if let icons = context.store.consumeOriginal("\(id).icons") {
            let v = (icons == "1" || icons.lowercased() == "true") ? "true" : "false"
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.finder", "CreateDesktop", "-bool", v])
            _ = try? context.runner.shell("/usr/bin/killall", ["Finder"])
        }
        if let dock = context.store.consumeOriginal("\(id).dock") {
            let v = (dock == "1" || dock.lowercased() == "true") ? "true" : "false"
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", v])
            _ = try? context.runner.shell("/usr/bin/killall", ["Dock"])
        }
    }
}

/// Sets the desktop wallpaper to a chosen image. Reversible: undo restores it.
public final class WallpaperSwapPrank: PrankModule {
    public let id = "wallpaperSwap"
    public let name = "Hintergrundbild tauschen"
    public let summary = "Setzt ein eigenes Bild als Schreibtischhintergrund."
    public let category = PrankCategory.ui
    public let intensity = Intensity.gentle
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .text("path", "Bildpfad", placeholder: "/Pfad/zum/Bild.jpg",
                  help: "Absoluter Pfad zu einer Bilddatei.", default: .string("")),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        let path = context.config.string(id, "path", "")
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            throw ScriptError.shell(code: 1, stderr: "Kein gültiger Bildpfad gesetzt.")
        }
        let wp = (try? context.runner.appleScript(
            "tell application \"System Events\" to get picture of current desktop")) ?? ""
        context.store.saveOriginal("\(id).wallpaper", value: wp)
        _ = try? context.runner.appleScript(
            "tell application \"System Events\" to set picture of every desktop to \"\(path)\"")
    }

    public func undo(context: PrankContext) throws {
        guard let wp = context.store.consumeOriginal("\(id).wallpaper"), !wp.isEmpty else { return }
        _ = try? context.runner.appleScript(
            "tell application \"System Events\" to set picture of every desktop to \"\(wp)\"")
    }
}

/// Switches between Light and Dark mode — or flickers between them on a timer.
/// Reversible: undo stops flicker and restores the original appearance.
public final class AppearanceTogglePrank: PrankModule {
    public let id = "appearanceToggle"
    public let name = "Hell/Dunkel umschalten"
    public let summary = "Wechselt das Erscheinungsbild — optional im Dauer-Flackern."
    public let category = PrankCategory.ui
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .choice("mode", "Modus", [
                .init("dark", "Auf Dunkel"),
                .init("light", "Auf Hell"),
                .init("flicker", "Flackern"),
            ], default: .string("flicker")),
            .slider("interval", "Flacker-Intervall", min: 1, max: 30, step: 1, unit: "s", default: .double(3)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.appearance")

    public init() {}

    private func setDark(_ on: Bool, context: PrankContext) {
        _ = try? context.runner.appleScript(
            "tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
    }

    public func run(context: PrankContext) throws {
        let original = (try? context.runner.appleScript(
            "tell application \"System Events\" to tell appearance preferences to get dark mode")) ?? "false"
        context.store.saveOriginal("\(id).dark", value: original)

        switch context.config.string(id, "mode", "flicker") {
        case "dark": setDark(true, context: context)
        case "light": setDark(false, context: context)
        default:
            let interval = context.config.double(id, "interval", 3)
            timer.start(interval: interval, fireImmediately: true) { [weak self] in
                let now = (try? context.runner.appleScript(
                    "tell application \"System Events\" to tell appearance preferences to get dark mode")) ?? "false"
                self?.setDark(now != "true", context: context)
            }
        }
    }

    public func undo(context: PrankContext) throws {
        timer.stop()
        let original = context.store.consumeOriginal("\(id).dark") ?? "false"
        setDark(original == "true", context: context)
    }
}

/// Messes with the Dock: position, auto-hide and magnification. Reversible.
public final class DockChaosPrank: PrankModule {
    public let id = "dockChaos"
    public let name = "Dock-Chaos"
    public let summary = "Verschiebt das Dock, blendet es aus oder vergrößert es absurd."
    public let category = PrankCategory.ui
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .choice("position", "Position", [
                .init("keep", "Unverändert"),
                .init("left", "Links"),
                .init("right", "Rechts"),
                .init("bottom", "Unten"),
            ], default: .string("right")),
            .toggle("autohide", "Automatisch ausblenden", default: .bool(false)),
            .toggle("magnify", "Riesen-Vergrößerung", default: .bool(true)),
            .intStepper("magnifySize", "Vergrößerung (px)", min: 48, max: 128, default: .int(128)),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        let orientation = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.dock", "orientation"])) ?? "bottom"
        let autohide = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.dock", "autohide"])) ?? "0"
        let magnification = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.dock", "magnification"])) ?? "0"
        let largesize = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.dock", "largesize"])) ?? "0"
        context.store.saveOriginal("\(id).orientation", value: orientation)
        context.store.saveOriginal("\(id).autohide", value: autohide)
        context.store.saveOriginal("\(id).magnification", value: magnification)
        context.store.saveOriginal("\(id).largesize", value: largesize)

        let position = context.config.string(id, "position", "right")
        if position != "keep" {
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "orientation", "-string", position])
        }
        let hide = context.config.bool(id, "autohide", false)
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", hide ? "true" : "false"])
        if context.config.bool(id, "magnify", true) {
            let size = context.config.int(id, "magnifySize", 128)
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "magnification", "-bool", "true"])
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "largesize", "-int", "\(size)"])
        }
        _ = try? context.runner.shell("/usr/bin/killall", ["Dock"])
    }

    public func undo(context: PrankContext) throws {
        if let v = context.store.consumeOriginal("\(id).orientation") {
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "orientation", "-string", v])
        }
        if let v = context.store.consumeOriginal("\(id).autohide") {
            let b = (v == "1" || v.lowercased() == "true") ? "true" : "false"
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", b])
        }
        if let v = context.store.consumeOriginal("\(id).magnification") {
            let b = (v == "1" || v.lowercased() == "true") ? "true" : "false"
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "magnification", "-bool", b])
        }
        if let v = context.store.consumeOriginal("\(id).largesize") {
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", "largesize", "-int", v])
        }
        _ = try? context.runner.shell("/usr/bin/killall", ["Dock"])
    }
}

/// Sets a hot corner so that moving the mouse there triggers something
/// (screensaver, sleep, …). Reversible: undo restores the corner's action.
public final class HotCornersPrank: PrankModule {
    public let id = "hotCorners"
    public let name = "Heiße Ecke"
    public let summary = "Eine Bildschirmecke löst plötzlich etwas aus, wenn die Maus sie berührt."
    public let category = PrankCategory.ui
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .choice("corner", "Ecke", [
                .init("tr", "Oben rechts"),
                .init("tl", "Oben links"),
                .init("br", "Unten rechts"),
                .init("bl", "Unten links"),
            ], default: .string("tr")),
            .choice("action", "Aktion", [
                .init("5", "Bildschirmschoner"),
                .init("10", "Display aus"),
                .init("3", "Alle Fenster"),
                .init("4", "Schreibtisch"),
            ], default: .string("5")),
        ]
    }

    private func key(_ corner: String) -> (String, String) {
        switch corner {
        case "tl": return ("wvous-tl-corner", "wvous-tl-modifier")
        case "br": return ("wvous-br-corner", "wvous-br-modifier")
        case "bl": return ("wvous-bl-corner", "wvous-bl-modifier")
        default: return ("wvous-tr-corner", "wvous-tr-modifier")
        }
    }

    public init() {}

    public func run(context: PrankContext) throws {
        let corner = context.config.string(id, "corner", "tr")
        let action = context.config.string(id, "action", "5")
        let (cornerKey, modKey) = key(corner)
        let curCorner = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.dock", cornerKey])) ?? "0"
        let curMod = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.dock", modKey])) ?? "0"
        context.store.saveOriginal("\(id).\(cornerKey)", value: curCorner)
        context.store.saveOriginal("\(id).\(modKey)", value: curMod)

        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", cornerKey, "-int", action])
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", modKey, "-int", "0"])
        _ = try? context.runner.shell("/usr/bin/killall", ["Dock"])
    }

    public func undo(context: PrankContext) throws {
        let corner = context.config.string(id, "corner", "tr")
        let (cornerKey, modKey) = key(corner)
        if let v = context.store.consumeOriginal("\(id).\(cornerKey)") {
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", cornerKey, "-int", v])
        }
        if let v = context.store.consumeOriginal("\(id).\(modKey)") {
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.dock", modKey, "-int", v])
        }
        _ = try? context.runner.shell("/usr/bin/killall", ["Dock"])
    }
}

/// Enlarges the mouse cursor. Reversible: undo restores the original size.
/// Note: macOS may only apply the new size after the next login.
public final class BigCursorPrank: PrankModule {
    public let id = "bigCursor"
    public let name = "Riesen-Mauszeiger"
    public let summary = "Vergrößert den Mauszeiger (wirkt ggf. erst nach erneuter Anmeldung)."
    public let category = PrankCategory.ui
    public let intensity = Intensity.gentle
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("size", "Größe", min: 1.0, max: 4.0, step: 0.5, unit: "×", default: .double(3.0)),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        let cur = (try? context.runner.shell("/usr/bin/defaults", ["read", "com.apple.universalaccess", "mouseDriverCursorSize"])) ?? "1"
        context.store.saveOriginal("\(id).size", value: cur)
        let size = context.config.double(id, "size", 3.0)
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.universalaccess", "mouseDriverCursorSize", "-float", "\(size)"])
    }

    public func undo(context: PrankContext) throws {
        let v = context.store.consumeOriginal("\(id).size") ?? "1"
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "com.apple.universalaccess", "mouseDriverCursorSize", "-float", v])
    }
}

/// Slows down window animations system-wide. Reversible. New apps pick up the
/// change as they launch.
public final class SlowAnimationsPrank: PrankModule {
    public let id = "slowAnimations"
    public let name = "Zeitlupen-Animationen"
    public let summary = "Macht Fenster-Animationen quälend langsam (gilt für neu gestartete Apps)."
    public let category = PrankCategory.ui
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("factor", "Dauer", min: 0.3, max: 3.0, step: 0.1, unit: "s", default: .double(1.5)),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        let cur = (try? context.runner.shell("/usr/bin/defaults", ["read", "-g", "NSWindowResizeTime"])) ?? ""
        context.store.saveOriginal("\(id).time", value: cur.isEmpty ? "DELETE" : cur)
        let factor = context.config.double(id, "factor", 1.5)
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "NSWindowResizeTime", "-float", "\(factor)"])
    }

    public func undo(context: PrankContext) throws {
        let v = context.store.consumeOriginal("\(id).time") ?? "DELETE"
        if v == "DELETE" {
            _ = try? context.runner.shell("/usr/bin/defaults", ["delete", "-g", "NSWindowResizeTime"])
        } else {
            _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "NSWindowResizeTime", "-float", v])
        }
    }
}

/// Launches the screensaver immediately, optionally re-launching it on a timer
/// so it keeps coming back. Reversible: undo stops the timer.
public final class ScreenSaverPrank: PrankModule {
    public let id = "screenSaver"
    public let name = "Bildschirmschoner"
    public let summary = "Startet sofort den Bildschirmschoner — optional immer wieder."
    public let category = PrankCategory.ui
    public let intensity = Intensity.gentle
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .toggle("repeat", "Immer wieder starten", default: .bool(false)),
            .slider("interval", "Intervall", min: 10, max: 600, step: 10, unit: "s", default: .double(60)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.screensaver")

    public init() {}

    private func launch(context: PrankContext) {
        _ = try? context.runner.shell("/usr/bin/open",
            ["-a", "/System/Library/CoreServices/ScreenSaverEngine.app"])
    }

    public func run(context: PrankContext) throws {
        launch(context: context)
        if context.config.bool(id, "repeat", false) {
            let interval = context.config.double(id, "interval", 60)
            timer.start(interval: interval) { [weak self] in self?.launch(context: context) }
        }
    }

    public func undo(context: PrankContext) throws { timer.stop() }
}

/// Repeatedly brings a chosen app to the foreground, stealing focus.
/// Reversible: undo stops the timer.
public final class AppActivatorPrank: PrankModule {
    public let id = "appActivator"
    public let name = "App drängt sich vor"
    public let summary = "Holt in Abständen eine bestimmte App in den Vordergrund."
    public let category = PrankCategory.ui
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .text("app", "App-Name", placeholder: "z. B. Chess", default: .string("Chess")),
            .slider("interval", "Intervall", min: 5, max: 300, step: 5, unit: "s", default: .double(30)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.appactivator")

    public init() {}

    public func run(context: PrankContext) throws {
        let interval = context.config.double(id, "interval", 30)
        timer.start(interval: interval, fireImmediately: true) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        let app = context.config.string(id, "app", "Chess")
        guard !app.isEmpty else { return }
        if (try? context.runner.appleScript("tell application \"\(app)\" to activate")) == nil {
            _ = try? context.runner.shell("/usr/bin/open", ["-a", app])
        }
    }
}
