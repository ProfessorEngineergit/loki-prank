import Foundation

/// Remembers the machine's original state before a prank changes it, so it can
/// be restored exactly — by the prank's own `undo`, or wholesale by the
/// `PanicManager`. Keys are namespaced by prank id, e.g. "flipScreen.rotation".
///
/// Values are persisted to disk so a restart (or a crash) never strands the
/// victim's machine in a pranked state — on next launch the saved originals are
/// still available to restore.
public final class StateStore {
    private let queue = DispatchQueue(label: "loki.statestore")
    private var values: [String: String] = [:]
    private let url: URL

    public init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Loki", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.url = dir.appendingPathComponent("state.json")
        }
        load()
    }

    /// Save an original value only if one isn't already stored for this key, so
    /// re-running a prank doesn't overwrite the true original with a pranked one.
    public func saveOriginal(_ key: String, value: String) {
        queue.sync {
            guard values[key] == nil else { return }
            values[key] = value
            persist()
        }
    }

    public func original(_ key: String) -> String? {
        queue.sync { values[key] }
    }

    /// Read the stored original and remove it (used by undo once restored).
    public func consumeOriginal(_ key: String) -> String? {
        queue.sync {
            let v = values[key]
            values[key] = nil
            persist()
            return v
        }
    }

    public func clear(_ key: String) {
        queue.sync {
            values[key] = nil
            persist()
        }
    }

    public var allKeys: [String] {
        queue.sync { Array(values.keys) }
    }

    private func persist() {
        guard let data = try? JSONSerialization.data(withJSONObject: values) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
        values = dict
    }
}
