import Foundation

/// A thread-safe repeating timer used by the many "do X every N seconds" pranks.
/// `stop()` is idempotent, so it's safe to call from `undo` even if the prank
/// never started.
public final class RepeatingTimer {
    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue

    public init(label: String) {
        self.queue = DispatchQueue(label: label)
    }

    public func start(interval: TimeInterval, fireImmediately: Bool = false, _ block: @escaping () -> Void) {
        queue.sync {
            timer?.cancel()
            let t = DispatchSource.makeTimerSource(queue: queue)
            let first: DispatchTime = fireImmediately ? .now() : .now() + interval
            t.schedule(deadline: first, repeating: interval)
            t.setEventHandler(handler: block)
            t.resume()
            timer = t
        }
    }

    public func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
        }
    }

    public var isRunning: Bool {
        queue.sync { timer != nil }
    }
}
