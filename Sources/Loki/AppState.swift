import Foundation
import SwiftUI
import LokiCore

/// Observable bridge between the SwiftUI UI and the LokiCore engine.
@MainActor
final class AppState: ObservableObject {
    let engine: PrankEngine
    let config: ConfigStore
    let modeRunner: ModeRunner
    let modes: [PrankMode]
    private let consentStore = ConsentStore()
    private let runner = ScriptRunner()

    @Published var hasConsented: Bool
    @Published var permissionsAcknowledged: Bool
    @Published var lastStatus: String = ""
    /// Bumped whenever active pranks change, to force list refresh.
    @Published private(set) var activeTick: Int = 0
    @Published private(set) var activeModeID: String?

    /// Minutes after starting a prank until Loki auto-reveals and restores
    /// everything. 0 = off. Persisted.
    @Published var autoRevealMinutes: Double {
        didSet {
            UserDefaults.standard.set(autoRevealMinutes, forKey: Self.autoRevealKey)
            engine.autoRevealMinutes = autoRevealMinutes
        }
    }
    private static let autoRevealKey = "loki.autoRevealMinutes"

    init() {
        let config = ConfigStore()
        self.config = config
        let engine = LokiFactory.makeEngine(config: config)
        self.engine = engine
        self.modeRunner = ModeRunner(engine: engine)
        self.modes = LokiFactory.allModes()
        self.hasConsented = consentStore.hasConsented
        self.permissionsAcknowledged = consentStore.permissionsAcknowledged
        let saved = UserDefaults.standard.object(forKey: Self.autoRevealKey) as? Double ?? 0
        self.autoRevealMinutes = saved
        engine.autoRevealMinutes = saved
        engine.onActiveChanged = { [weak self] in
            self?.activeTick += 1
        }
        engine.onAutoReveal = { [weak self] in
            self?.performAutoReveal()
        }
        modeRunner.onChange = { [weak self] in
            self?.activeModeID = self?.modeRunner.activeModeID
        }
    }

    // MARK: Permissions

    func acknowledgePermissions() {
        consentStore.permissionsAcknowledged = true
        permissionsAcknowledged = true
    }

    func requestAccessibility() {
        PermissionsManager.requestAccessibility()
        // The system prompt only appears once ever; open the pane so a previous
        // denial can still be toggled on.
        PermissionsManager.openPrivacySettings(.accessibility)
    }
    func requestScreenRecording() {
        PermissionsManager.requestScreenRecording()
        PermissionsManager.openPrivacySettings(.screenRecording)
    }
    func requestAutomation() { PermissionsManager.requestAutomation(runner: runner) }
    func requestVoice() { PermissionsManager.requestVoiceReply { _ in } }
    var hasAccessibility: Bool { PermissionsManager.isAccessibilityTrusted() }
    var hasScreenRecording: Bool { PermissionsManager.hasScreenRecording() }
    var hasVoice: Bool { PermissionsManager.hasMicrophone() && PermissionsManager.hasSpeechRecognition() }

    // MARK: Modes

    func startMode(_ mode: PrankMode) {
        guard hasConsented else { return }
        modeRunner.start(mode)
        lastStatus = "Modus „\(mode.name)“ läuft …"
    }

    func stopMode() {
        modeRunner.stop()
        lastStatus = "Modus gestoppt & zurückgesetzt"
    }

    func isModeActive(_ mode: PrankMode) -> Bool { activeModeID == mode.id }

    /// Fired by the engine's auto-reveal timer: disclose, then restore everything.
    private func performAutoReveal() {
        try? engine.run(id: "reveal")
        let errors = engine.panic()
        lastStatus = errors.isEmpty
            ? "🎭 Auto-Auflösung: alles zurückgesetzt"
            : "Auto-Auflösung mit \(errors.count) Fehler(n)"
    }

    var pranks: [PrankModule] { engine.all }

    func isActive(_ prank: PrankModule) -> Bool { engine.isActive(prank.id) }

    func accept() {
        consentStore.hasConsented = true
        hasConsented = true
    }

    func toggle(_ prank: PrankModule) {
        guard hasConsented else { return }
        do {
            try engine.toggle(id: prank.id)
            lastStatus = engine.isActive(prank.id)
                ? "▶︎ \(prank.name) aktiv"
                : "■ \(prank.name) gestoppt"
        } catch {
            lastStatus = "Fehler: \(error.localizedDescription)"
        }
    }

    // MARK: Settings bindings

    func resetSettings(_ prank: PrankModule) {
        for s in prank.settings {
            config.set(s.defaultValue, prank: prank.id, setting: s.key)
        }
        objectWillChange.send()
    }

    func doubleBinding(_ p: PrankModule, _ s: PrankSetting) -> Binding<Double> {
        Binding(
            get: {
                if case .double(let v) = self.config.value(prank: p.id, setting: s) { return v }
                return 0
            },
            set: { self.config.set(.double($0), prank: p.id, setting: s.key); self.objectWillChange.send() }
        )
    }

    func intBinding(_ p: PrankModule, _ s: PrankSetting) -> Binding<Int> {
        Binding(
            get: {
                if case .int(let v) = self.config.value(prank: p.id, setting: s) { return v }
                return 0
            },
            set: { self.config.set(.int($0), prank: p.id, setting: s.key); self.objectWillChange.send() }
        )
    }

    func boolBinding(_ p: PrankModule, _ s: PrankSetting) -> Binding<Bool> {
        Binding(
            get: {
                if case .bool(let v) = self.config.value(prank: p.id, setting: s) { return v }
                return false
            },
            set: { self.config.set(.bool($0), prank: p.id, setting: s.key); self.objectWillChange.send() }
        )
    }

    func stringBinding(_ p: PrankModule, _ s: PrankSetting) -> Binding<String> {
        Binding(
            get: {
                if case .string(let v) = self.config.value(prank: p.id, setting: s) { return v }
                return ""
            },
            set: { self.config.set(.string($0), prank: p.id, setting: s.key); self.objectWillChange.send() }
        )
    }

    /// Stop everything and restore original state.
    func panic() {
        let errors = engine.panic()
        lastStatus = errors.isEmpty
            ? "PANIK: alles gestoppt & wiederhergestellt"
            : "PANIK mit \(errors.count) Fehler(n) — prüfe Zustand manuell"
    }
}
