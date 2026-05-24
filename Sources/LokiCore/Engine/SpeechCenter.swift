import Foundation

/// Serializes ALL spoken output so multiple pranks (companion, watcher, mode
/// narration, reveal) never talk over each other — the #1 reason the haunt
/// sounded broken. One `say` runs at a time; queued lines play in order. A
/// generation token lets `stopAll()` (panic) instantly drop everything that
/// hasn't been spoken yet and kill the line in progress.
public final class SpeechCenter {
    public static let shared = SpeechCenter()

    private let queue = DispatchQueue(label: "loki.speech")
    private let lock = NSLock()
    private var current: Process?
    private var generation = 0
    private var pending = 0
    private let maxPending = 4

    public init() {}

    /// Speak `text`. If `interrupt` is true, cut off whatever is speaking and
    /// jump the queue (used for the reveal and the watcher's live reactions).
    public func say(_ text: String, voice: String = "", rate: Int? = nil, interrupt: Bool = false) {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }

        if interrupt { stopAll() }

        lock.lock()
        if pending >= maxPending && !interrupt { lock.unlock(); return }
        pending += 1
        let gen = generation
        lock.unlock()

        queue.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let stale = gen != self.generation
            if stale { self.pending = max(0, self.pending - 1); self.lock.unlock(); return }
            self.lock.unlock()

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            var args: [String] = []
            if !voice.isEmpty { args += ["-v", voice] }
            if let rate { args += ["-r", "\(rate)"] }
            args.append(line)
            process.arguments = args

            self.lock.lock(); self.current = process; self.lock.unlock()
            try? process.run()
            process.waitUntilExit()
            self.lock.lock()
            self.current = nil
            self.pending = max(0, self.pending - 1)
            self.lock.unlock()
        }
    }

    /// Immediately stop the current line and discard everything queued.
    public func stopAll() {
        lock.lock()
        generation += 1
        pending = 0
        let process = current
        current = nil
        lock.unlock()
        process?.terminate()
    }
}
