import Foundation

/// Rotates the main display 180°. Requires the `displayplacer` CLI
/// (https://github.com/jakehilborn/displayplacer, `brew install displayplacer`).
/// Reversible: undo restores the original rotation degree.
public final class FlipScreenPrank: PrankModule {
    public let id = "flipScreen"
    public let name = "Bildschirm umdrehen"
    public let summary = "Dreht den Hauptbildschirm um 180°."
    public let category = PrankCategory.ui
    public let intensity = Intensity.hacky
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .choice("degree", "Drehung", [
                .init("90", "90° (links)"),
                .init("180", "180° (kopfüber)"),
                .init("270", "270° (rechts)"),
            ], help: "Um wie viel Grad der Bildschirm gedreht wird.", default: .string("180")),
        ]
    }

    private let degreeKey = "flipScreen.degree"

    public init() {}

    private func displayplacerPath() -> String? {
        ["/opt/homebrew/bin/displayplacer", "/usr/local/bin/displayplacer"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func run(context: PrankContext) throws {
        guard let dp = displayplacerPath() else {
            throw ScriptError.shell(code: 1, stderr:
                "displayplacer nicht gefunden. Installiere es mit: brew install displayplacer")
        }
        let target = context.config.string(id, "degree", "180")
        let (screenID, degree) = try currentMainDisplay(dp: dp, context: context)
        context.store.saveOriginal(degreeKey, value: "\(screenID)|\(degree)")
        try context.runner.shell(dp, ["id:\(screenID) degree:\(target)"])
    }

    public func undo(context: PrankContext) throws {
        guard let dp = displayplacerPath() else { return }
        guard let saved = context.store.consumeOriginal(degreeKey) else { return }
        let parts = saved.split(separator: "|")
        guard parts.count == 2 else { return }
        try context.runner.shell(dp, ["id:\(parts[0]) degree:\(parts[1])"])
    }

    /// Parse `displayplacer list` for the first display's persistent id and
    /// current rotation degree.
    private func currentMainDisplay(dp: String, context: PrankContext) throws -> (id: String, degree: String) {
        let listing = try context.runner.shell(dp, ["list"])
        var screenID: String?
        var degree = "0"
        for line in listing.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if screenID == nil, trimmed.hasPrefix("Persistent screen id:") {
                screenID = trimmed.replacingOccurrences(of: "Persistent screen id:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            if trimmed.hasPrefix("Rotation:") {
                // e.g. "Rotation: 0 degrees - rotate internal screen..."
                let after = trimmed.replacingOccurrences(of: "Rotation:", with: "")
                degree = after.trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ").first ?? "0"
                break
            }
        }
        guard let id = screenID else {
            throw ScriptError.shell(code: 1, stderr: "Kein Display in displayplacer-Ausgabe gefunden.")
        }
        return (id, degree)
    }
}
