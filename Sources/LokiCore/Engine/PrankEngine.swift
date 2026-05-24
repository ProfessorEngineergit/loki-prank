import Foundation

/// Runtime that owns the prank catalog, runs and reverses pranks, and tracks
/// which ones are currently active so the `PanicManager` can stop everything.
public final class PrankEngine {
    public let context: PrankContext
    private let queue = DispatchQueue(label: "loki.engine")
    private var catalog: [String: PrankModule] = [:]
    private var order: [String] = []
    private var activeIDs: Set<String> = []

    /// Called on the main thread whenever the set of active pranks changes, so
    /// UI can refresh. Set by the app layer.
    public var onActiveChanged: (() -> Void)?

    /// Safety auto-reveal: minutes after a prank is started, the operator wants
    /// the bit to resolve itself. 0 = off. Each new prank start re-arms the
    /// countdown. When it fires, `onAutoReveal` is called on the main thread
    /// (the app shows the reveal and restores everything).
    public var autoRevealMinutes: Double = 0 {
        didSet { if autoRevealMinutes <= 0 { cancelAutoReveal() } }
    }
    public var onAutoReveal: (() -> Void)?
    private var revealTimer: DispatchSourceTimer?
    private let revealQueue = DispatchQueue(label: "loki.autoreveal")

    public init(context: PrankContext) {
        self.context = context
    }

    // MARK: Catalog

    public func register(_ prank: PrankModule) {
        queue.sync {
            if catalog[prank.id] == nil { order.append(prank.id) }
            catalog[prank.id] = prank
        }
    }

    public func register(_ pranks: [PrankModule]) {
        pranks.forEach(register)
    }

    public var all: [PrankModule] {
        queue.sync { order.compactMap { catalog[$0] } }
    }

    public func prank(id: String) -> PrankModule? {
        queue.sync { catalog[id] }
    }

    public func isActive(_ id: String) -> Bool {
        queue.sync { activeIDs.contains(id) }
    }

    public var activePranks: [PrankModule] {
        queue.sync { activeIDs.compactMap { catalog[$0] } }
    }

    // MARK: Run / undo

    public func run(id: String) throws {
        guard let prank = prank(id: id) else { return }
        try prank.run(context: context)
        if prank.isReversible {
            queue.sync { _ = activeIDs.insert(id) }
            notify()
        }
        // Don't let the reveal re-arm itself into a loop.
        if id != "reveal" { armAutoReveal() }
    }

    public func undo(id: String) throws {
        guard let prank = prank(id: id) else { return }
        try prank.undo(context: context)
        let stillActive = queue.sync { () -> Bool in
            activeIDs.remove(id)
            return !activeIDs.isEmpty
        }
        if !stillActive { cancelAutoReveal() }
        notify()
    }

    /// Toggle a reversible prank; run a one-shot prank.
    public func toggle(id: String) throws {
        if isActive(id) {
            try undo(id: id)
        } else {
            try run(id: id)
        }
    }

    /// Stop EVERYTHING and restore original state. Best-effort: a failure in one
    /// prank's undo must not prevent the others from being reversed. Returns any
    /// errors encountered for surfacing to the operator.
    @discardableResult
    public func panic() -> [Error] {
        // Silence everything first so the reveal / restore isn't drowned out.
        SpeechCenter.shared.stopAll()
        var errors: [Error] = []
        for prank in activePranks {
            do {
                try prank.undo(context: context)
            } catch {
                errors.append(error)
            }
        }
        queue.sync { activeIDs.removeAll() }
        cancelAutoReveal()
        notify()
        return errors
    }

    // MARK: Auto-reveal timer

    private func armAutoReveal() {
        guard autoRevealMinutes > 0 else { return }
        let seconds = autoRevealMinutes * 60
        revealQueue.sync {
            revealTimer?.cancel()
            let t = DispatchSource.makeTimerSource(queue: revealQueue)
            t.schedule(deadline: .now() + seconds)
            t.setEventHandler { [weak self] in
                self?.revealQueue.async { self?.revealTimer = nil }
                let cb = self?.onAutoReveal
                DispatchQueue.main.async { cb?() }
            }
            t.resume()
            revealTimer = t
        }
    }

    private func cancelAutoReveal() {
        revealQueue.sync {
            revealTimer?.cancel()
            revealTimer = nil
        }
    }

    /// Seconds remaining until the auto-reveal fires, or nil if not armed.
    public var autoRevealArmed: Bool {
        revealQueue.sync { revealTimer != nil }
    }

    private func notify() {
        let cb = onActiveChanged
        DispatchQueue.main.async { cb?() }
    }
}
