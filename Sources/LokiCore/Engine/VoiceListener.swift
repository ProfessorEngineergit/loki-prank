import Foundation
import Speech
import AVFoundation

/// On-device speech recognition so the user can talk back to the companion.
/// Uses Apple's Speech framework with `requiresOnDeviceRecognition` where
/// available — audio is processed locally and never uploaded. Microphone +
/// Speech Recognition permissions are required; without them it simply stays
/// silent (no crash).
public final class VoiceListener {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var shouldRun = false

    /// Called on the main thread with a finished utterance.
    public var onTranscript: ((String) -> Void)?

    public init() {}

    /// Requests Speech + Microphone access. Calls back with whether both granted.
    public static func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            let speechOK = status == .authorized
            AVCaptureDevice.requestAccess(for: .audio) { micOK in
                DispatchQueue.main.async { completion(speechOK && micOK) }
            }
        }
    }

    public var isAvailable: Bool { recognizer?.isAvailable == true }

    /// Begin continuous listening (restarts itself after each utterance). Must
    /// be called on the main thread.
    public func start() {
        shouldRun = true
        beginSession()
    }

    public func stop() {
        shouldRun = false
        endSession()
    }

    private func beginSession() {
        guard shouldRun, let recognizer, recognizer.isAvailable else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            endSession()
            return
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result, result.isFinal {
                let text = result.bestTranscription.formattedString
                if !text.isEmpty {
                    DispatchQueue.main.async { self.onTranscript?(text) }
                }
                self.cycle()
            } else if error != nil {
                self.cycle()
            }
        }
    }

    /// End the current recognition and, if still wanted, start a fresh one.
    private func cycle() {
        endSession()
        guard shouldRun else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.beginSession()
        }
    }

    private func endSession() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
    }
}
