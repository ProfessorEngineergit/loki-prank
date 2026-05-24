import Foundation
import CoreGraphics
import Vision
import AppKit

/// A coarse snapshot of what the user is doing right now. Deliberately
/// low-resolution about content: it answers "is the mouse moving / is someone
/// typing / which app is in front", not "what are they writing".
public struct AwarenessSnapshot: Sendable {
    public var mouseMoved: Bool
    public var idleSeconds: Double
    public var frontApp: String
    public var frontAppChanged: Bool
    public var typing: Bool
    /// A few words read locally from the screen, only if vision is enabled.
    public var words: [String]
}

/// Lightweight, **fully on-device** awareness of user activity, used by the
/// Watcher prank to make the haunt feel like it reacts to you.
///
/// Privacy stance (this is the line that keeps Loki a prank, not spyware):
/// - Nothing is ever transmitted or persisted. Everything stays in memory.
/// - The keyboard monitor only records *that* a key was pressed (a timestamp),
///   never which key — it is not a keylogger.
/// - Vision (local Apple OCR) is OFF by default and only reads a few words to
///   weave into a taunt; it never stores or sends anything.
/// `VisionProvider` is the extension point for plugging a richer local model later.
public protocol VisionProvider {
    func words() -> [String]
}

public final class ScreenAwareness {
    public var useVision = false
    public var useKeyboard = false
    /// Optional richer local model; falls back to built-in Apple Vision OCR.
    public var visionProvider: VisionProvider?

    private var lastMouse = CGPoint.zero
    private var lastActivity = Date()
    private var lastFrontApp = ""
    private var cachedFrontApp = ""
    private var lastKeyTime = Date.distantPast
    private var keyMonitor: Any?
    private var appObserver: Any?

    public init() {}

    public func start() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cachedFrontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
            self.appObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
            ) { [weak self] note in
                let app = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.localizedName
                self?.cachedFrontApp = app ?? self?.cachedFrontApp ?? ""
            }
            if self.useKeyboard {
                // Listen-only: record the time of any key press, never the key.
                self.keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
                    self?.lastKeyTime = Date()
                }
            }
            self.lastMouse = CGEvent(source: nil)?.location ?? .zero
            self.lastActivity = Date()
        }
    }

    public func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let m = self.keyMonitor { NSEvent.removeMonitor(m); self.keyMonitor = nil }
            if let o = self.appObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(o)
                self.appObserver = nil
            }
        }
    }

    public func snapshot() -> AwarenessSnapshot {
        let loc = CGEvent(source: nil)?.location ?? .zero
        let moved = hypot(loc.x - lastMouse.x, loc.y - lastMouse.y) > 3
        if moved { lastActivity = Date(); lastMouse = loc }
        let idle = Date().timeIntervalSince(lastActivity)

        let app = cachedFrontApp
        let appChanged = !app.isEmpty && app != lastFrontApp && !lastFrontApp.isEmpty
        lastFrontApp = app

        let typing = useKeyboard && Date().timeIntervalSince(lastKeyTime) < 2.0

        var words: [String] = []
        if useVision {
            words = visionProvider?.words() ?? AppleVisionOCR.shared.words()
        }

        return AwarenessSnapshot(mouseMoved: moved, idleSeconds: idle, frontApp: app,
                                 frontAppChanged: appChanged, typing: typing, words: words)
    }

    /// Turn a snapshot into a creepy, context-aware line — or nil to stay quiet
    /// this tick (so it doesn't talk nonstop).
    public func reactiveLine(_ s: AwarenessSnapshot) -> String? {
        // Build context-matched candidates; the most specific signals first.
        var candidates: [String] = []

        if let word = s.words.randomElement() {
            candidates += ["Klick bloß nicht auf „\(word)“ … klick HIER.",
                           "„\(word)“ … das würde ich an deiner Stelle lassen.",
                           "Ich sehe „\(word)“ auf deinem Bildschirm. Interessant."]
        }
        if s.frontAppChanged && !s.frontApp.isEmpty {
            candidates += ["Warum öffnest du \(s.frontApp)?",
                           "\(s.frontApp)? Das bringt dir jetzt auch nichts mehr."]
        }
        if s.typing {
            candidates += ["Ich lese jedes Wort mit, das du tippst.",
                           "Tipp ruhig weiter. Ich notiere alles.",
                           "Schöner Satz. Schade drum."]
        }
        if s.idleSeconds > 1.2 && !s.mouseMoved {
            candidates += ["Haha — beweg dich gar nicht weg.",
                           "Warum hast du aufgehört? Ich beobachte dich.",
                           "Steh ganz still. Ich sehe dich."]
        }
        if s.mouseMoved {
            candidates += ["Wohin so eilig?", "Diese Maus gehorcht gleich mir.",
                           "Ich folge deinem Cursor."]
        }
        // Fallback so the watcher rarely goes silent and never feels "broken".
        if candidates.isEmpty {
            candidates += ["Ich bin immer noch hier.", "Ich beobachte dich weiter.",
                           "Du bist nicht allein an diesem Rechner."]
        }
        // Occasionally stay quiet so it isn't relentless (~15%).
        if Int.random(in: 0..<100) < 15 { return nil }
        return candidates.randomElement()
    }
}

/// Built-in, on-device OCR using Apple's Vision framework. No model download,
/// no network. Reads a downscaled frame of the main display and returns a few
/// words. Requires Screen Recording permission; returns [] otherwise.
final class AppleVisionOCR: VisionProvider {
    static let shared = AppleVisionOCR()

    func words() -> [String] {
        guard CGPreflightScreenCaptureAccess() else { return [] }
        guard let full = captureMainDisplay(), let small = downscale(full, maxWidth: 1000) else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: small, options: [:])
        try? handler.perform([request])
        let lines = (request.results ?? []).prefix(40).compactMap { $0.topCandidates(1).first?.string }
        let words = lines.flatMap { $0.split(separator: " ") }.map(String.init).filter { $0.count > 3 }
        return Array(Set(words)).shuffled().prefix(5).map { $0 }
    }

    private func captureMainDisplay() -> CGImage? {
        // CGDisplayCreateImage is the lightest local capture path. Vision is an
        // opt-in feature, so a deprecation here is acceptable for v1.
        CGDisplayCreateImage(CGMainDisplayID())
    }

    private func downscale(_ image: CGImage, maxWidth: CGFloat) -> CGImage? {
        let scale = min(1, maxWidth / CGFloat(image.width))
        if scale >= 1 { return image }
        let w = Int(CGFloat(image.width) * scale)
        let h = Int(CGFloat(image.height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
