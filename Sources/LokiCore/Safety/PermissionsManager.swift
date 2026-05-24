import Foundation
import CoreGraphics
import ApplicationServices
import Speech
import AVFoundation

/// Requests and checks the macOS privacy permissions Loki's pranks need.
/// Everything here is transparent: each request triggers the normal system
/// prompt, and the onboarding UI explains why each permission is needed.
public enum PermissionsManager {

    public enum Status { case granted, notGranted, unknown }

    // MARK: Accessibility (mouse/keyboard simulation, UI scripting)

    public static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts for Accessibility (shows the system dialog with a "Open System
    /// Settings" button). Returns the current trust state.
    @discardableResult
    public static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    // MARK: Screen Recording (the wallpaper-freeze prank)

    public static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    public static func requestScreenRecording() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    // MARK: Automation / Apple Events (browsers, System Events, Notes, …)

    /// Triggers the Automation consent prompt by sending a harmless Apple Event
    /// to System Events. Returns true if it succeeded (i.e. permission granted).
    @discardableResult
    public static func requestAutomation(runner: ScriptRunner) -> Bool {
        let result = try? runner.appleScript(
            "tell application \"System Events\" to get name of first application process whose frontmost is true")
        return result != nil
    }

    // MARK: Microphone + Speech (the talking companion's voice replies)

    public static func hasMicrophone() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public static func hasSpeechRecognition() -> Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    /// Requests both Speech Recognition and Microphone (the companion needs both
    /// to hear and answer). Calls back with whether both were granted.
    public static func requestVoiceReply(_ completion: @escaping (Bool) -> Void) {
        VoiceListener.requestAuthorization(completion)
    }

    /// Opens a specific Privacy pane in System Settings.
    public static func openPrivacySettings(_ pane: PrivacyPane) {
        guard let url = URL(string: pane.urlString) else { return }
        #if canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }

    public enum PrivacyPane {
        case accessibility, screenRecording, automation
        var urlString: String {
            switch self {
            case .accessibility:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .screenRecording:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .automation:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
            }
        }
    }
}

#if canImport(AppKit)
import AppKit
#endif
