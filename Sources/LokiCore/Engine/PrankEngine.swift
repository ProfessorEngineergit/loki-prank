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
    }

    public func undo(id: String) throws {
        guard let prank = prank(id: id) else { return }
        try prank.undo(context: context)
        queue.sync { _ = activeIDs.remove(id) }
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
        var errors: [Error] = []
        for prank in activePranks {
            do {
                try prank.undo(context: context)
            } catch {
                errors.append(error)
            }
        }
        queue.sync { activeIDs.removeAll() }
        notify()
        return errors
    }

    private func notify() {
        let cb = onActiveChanged
        DispatchQueue.main.async { cb?() }
    }
}
