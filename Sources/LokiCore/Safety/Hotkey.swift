import Carbon.HIToolbox
import Foundation

/// Registers a single global hotkey via Carbon's `RegisterEventHotKey`, which
/// works system-wide without Accessibility permission. Used for the panic
/// shortcut and to summon the hidden overlay.
public final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: () -> Void
    private let id: UInt32

    private static var registry: [UInt32: GlobalHotkey] = [:]
    private static var nextID: UInt32 = 1
    private static var dispatcherInstalled = false

    /// - Parameters:
    ///   - keyCode: a Carbon virtual key code (e.g. `UInt32(kVK_ANSI_P)`).
    ///   - modifiers: Carbon modifier flags (e.g. `cmdKey | optionKey | controlKey`).
    public init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        self.id = GlobalHotkey.nextID
        GlobalHotkey.nextID += 1
        GlobalHotkey.installDispatcherIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4C4F4B49 /* 'LOKI' */), id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetEventDispatcherTarget(), 0, &hotKeyRef)
        guard status == noErr else { return nil }
        GlobalHotkey.registry[id] = self
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        GlobalHotkey.registry[id] = nil
    }

    private static func installDispatcherIfNeeded() {
        guard !dispatcherInstalled else { return }
        dispatcherInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            GlobalHotkey.registry[hkID.id]?.handler()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
