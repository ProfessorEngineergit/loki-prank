import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Nudges the mouse cursor by a small random offset at intervals, so it seems
/// to drift on its own. Reversible: undo stops the timer.
public final class CursorJumpPrank: PrankModule {
    public let id = "cursorJump"
    public let name = "Maus-Drift"
    public let summary = "Schubst den Mauszeiger in Abständen ein Stück in eine zufällige Richtung."
    public let category = PrankCategory.input
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .intStepper("magnitude", "Stärke (px)", min: 5, max: 400, default: .int(80)),
            .slider("interval", "Intervall", min: 0.5, max: 30, step: 0.5, unit: "s", default: .double(3)),
            .slider("probability", "Wahrscheinlichkeit", min: 0.1, max: 1.0, step: 0.1, default: .double(0.6)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.cursor")

    public init() {}

    public func run(context: PrankContext) throws {
        let interval = context.config.double(id, "interval", 3)
        timer.start(interval: interval) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        guard Double.random(in: 0..<1) < context.config.double(id, "probability", 0.6) else { return }
        let mag = CGFloat(context.config.int(id, "magnitude", 80))
        let loc = CGEvent(source: nil)?.location ?? .zero
        let target = CGPoint(x: loc.x + .random(in: -mag...mag),
                             y: loc.y + .random(in: -mag...mag))
        CGWarpMouseCursorPosition(target)
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    }
}

/// Reverses the natural scroll direction. Reversible: undo restores it.
/// Note: macOS may apply scroll-direction changes only after the next login.
public final class ReverseScrollPrank: PrankModule {
    public let id = "reverseScroll"
    public let name = "Scroll-Richtung umkehren"
    public let summary = "Dreht die Scroll-Richtung um (wirkt ggf. erst nach erneuter Anmeldung)."
    public let category = PrankCategory.input
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public init() {}

    public func run(context: PrankContext) throws {
        let cur = (try? context.runner.shell("/usr/bin/defaults", ["read", "-g", "com.apple.swipescrolldirection"])) ?? "1"
        context.store.saveOriginal("\(id).dir", value: cur)
        let reversed = (cur == "1" || cur.lowercased() == "true") ? "false" : "true"
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "com.apple.swipescrolldirection", "-bool", reversed])
    }

    public func undo(context: PrankContext) throws {
        let v = context.store.consumeOriginal("\(id).dir") ?? "1"
        let b = (v == "1" || v.lowercased() == "true") ? "true" : "false"
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "com.apple.swipescrolldirection", "-bool", b])
    }
}

/// Changes the key-repeat speed to an extreme. Reversible: undo restores it.
/// Note: applications pick up the change when they next launch.
public final class KeyRepeatChaosPrank: PrankModule {
    public let id = "keyRepeatChaos"
    public let name = "Tasten-Wiederholung"
    public let summary = "Stellt die Tastenwiederholung extrem schnell oder schneckenlangsam (gilt für neu gestartete Apps)."
    public let category = PrankCategory.input
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .choice("mode", "Modus", [
                .init("fast", "Irrsinnig schnell"),
                .init("slow", "Quälend langsam"),
            ], default: .string("fast")),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        for key in ["KeyRepeat", "InitialKeyRepeat"] {
            let cur = (try? context.runner.shell("/usr/bin/defaults", ["read", "-g", key])) ?? ""
            context.store.saveOriginal("\(id).\(key)", value: cur.isEmpty ? "DELETE" : cur)
        }
        let fast = context.config.string(id, "mode", "fast") == "fast"
        let keyRepeat = fast ? "1" : "120"
        let initial = fast ? "10" : "120"
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "KeyRepeat", "-int", keyRepeat])
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "InitialKeyRepeat", "-int", initial])
    }

    public func undo(context: PrankContext) throws {
        for key in ["KeyRepeat", "InitialKeyRepeat"] {
            let v = context.store.consumeOriginal("\(id).\(key)") ?? "DELETE"
            if v == "DELETE" {
                _ = try? context.runner.shell("/usr/bin/defaults", ["delete", "-g", key])
            } else {
                _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", key, "-int", v])
            }
        }
    }
}

/// Sets the pointer tracking speed to an extreme. Reversible: undo restores it.
public final class TrackingSpeedPrank: PrankModule {
    public let id = "trackingSpeed"
    public let name = "Maus-Geschwindigkeit"
    public let summary = "Stellt die Zeiger-Geschwindigkeit extrem schnell oder schleichend langsam."
    public let category = PrankCategory.input
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("speed", "Geschwindigkeit", min: 0.0, max: 12.0, step: 0.5,
                    help: "0 = extrem langsam, 12 = unkontrollierbar schnell.", default: .double(12.0)),
        ]
    }

    public init() {}

    public func run(context: PrankContext) throws {
        for key in ["com.apple.trackpad.scaling", "com.apple.mouse.scaling"] {
            let cur = (try? context.runner.shell("/usr/bin/defaults", ["read", "-g", key])) ?? ""
            context.store.saveOriginal("\(id).\(key)", value: cur.isEmpty ? "DELETE" : cur)
        }
        let speed = context.config.double(id, "speed", 12.0)
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "com.apple.trackpad.scaling", "-float", "\(speed)"])
        _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", "com.apple.mouse.scaling", "-float", "\(speed)"])
    }

    public func undo(context: PrankContext) throws {
        for key in ["com.apple.trackpad.scaling", "com.apple.mouse.scaling"] {
            let v = context.store.consumeOriginal("\(id).\(key)") ?? "DELETE"
            if v == "DELETE" {
                _ = try? context.runner.shell("/usr/bin/defaults", ["delete", "-g", key])
            } else {
                _ = try? context.runner.shell("/usr/bin/defaults", ["write", "-g", key, "-float", v])
            }
        }
    }
}

/// Switches the active keyboard layout to a different installed one (e.g. a
/// layout where the letters are in the "wrong" place). Reversible: undo
/// re-selects the original layout. Requires a second layout to be installed.
public final class SwapKeyboardLayoutPrank: PrankModule {
    public let id = "swapKeyboardLayout"
    public let name = "Tastaturbelegung tauschen"
    public let summary = "Wechselt auf eine andere installierte Tastaturbelegung (zweite Belegung muss vorhanden sein)."
    public let category = PrankCategory.input
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public init() {}

    private func currentSourceID() -> String? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private func selectableLayouts() -> [(id: String, source: TISInputSource)] {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable: true,
        ]
        guard let cfList = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() else { return [] }
        let count = CFArrayGetCount(cfList)
        var result: [(String, TISInputSource)] = []
        for i in 0..<count {
            let raw = CFArrayGetValueAtIndex(cfList, i)
            let source = Unmanaged<TISInputSource>.fromOpaque(raw!).takeUnretainedValue()
            if let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let sid = Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
                result.append((sid, source))
            }
        }
        return result
    }

    private func select(id targetID: String) {
        if let match = selectableLayouts().first(where: { $0.id == targetID }) {
            TISSelectInputSource(match.source)
        }
    }

    public func run(context: PrankContext) throws {
        guard let current = currentSourceID() else {
            throw ScriptError.shell(code: 1, stderr: "Aktuelle Tastaturbelegung nicht ermittelbar.")
        }
        guard let other = selectableLayouts().first(where: { $0.id != current }) else {
            throw ScriptError.shell(code: 1, stderr:
                "Keine zweite Tastaturbelegung installiert. Füge eine in den Systemeinstellungen hinzu.")
        }
        context.store.saveOriginal("\(id).layout", value: current)
        TISSelectInputSource(other.source)
    }

    public func undo(context: PrankContext) throws {
        guard let original = context.store.consumeOriginal("\(id).layout") else { return }
        select(id: original)
    }
}
