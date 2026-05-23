import SwiftUI
import AppKit
import Carbon.HIToolbox
import LokiCore

@main
struct LokiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Loki", systemImage: "theatermasks") {
            Button("Steuerung öffnen (⌃⌥⌘L)") { delegate.toggleOverlay() }
            Divider()
            Button("PANIK — alles stoppen (⌃⌥⌘P)") { delegate.appState.panic() }
            Divider()
            Button("Beenden") { NSApp.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var overlayWindow: NSWindow?
    private var panicHotkey: GlobalHotkey?
    private var overlayHotkey: GlobalHotkey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the dock icon — Loki lives in the menu bar / behind a hotkey.
        NSApp.setActivationPolicy(.accessory)

        // Carbon modifier masks.
        let mods = UInt32(cmdKey | optionKey | controlKey)
        panicHotkey = GlobalHotkey(keyCode: UInt32(kVK_ANSI_P), modifiers: mods) { [weak self] in
            DispatchQueue.main.async { self?.appState.panic() }
        }
        overlayHotkey = GlobalHotkey(keyCode: UInt32(kVK_ANSI_L), modifiers: mods) { [weak self] in
            DispatchQueue.main.async { self?.toggleOverlay() }
        }

        // On first launch, show the overlay so onboarding (consent + permissions)
        // is visible without needing the hotkey.
        if !appState.hasConsented || !appState.permissionsAcknowledged {
            showOverlay()
        }
    }

    func toggleOverlay() {
        if let w = overlayWindow, w.isVisible {
            w.orderOut(nil)
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        if overlayWindow == nil {
            let host = NSHostingController(rootView: OverlayView().environmentObject(appState))
            let window = NSWindow(contentViewController: host)
            window.title = "Loki"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.center()
            overlayWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow?.makeKeyAndOrderFront(nil)
    }
}
