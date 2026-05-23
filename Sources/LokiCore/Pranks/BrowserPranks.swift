import Foundation

/// Opens a burst of (funny) tabs in the chosen browser at intervals.
/// Reversible: undo stops the timer (already-open tabs are left for the victim
/// to close — closing them automatically could discard their real tabs).
public final class TabFloodPrank: PrankModule {
    public let id = "tabFlood"
    public let name = "Tab-Flut"
    public let summary = "Öffnet immer wieder neue Tabs mit zufälligen URLs."
    public let category = PrankCategory.browser
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = []
    public let isReversible = true

    private static let defaultURLs = [
        "https://hackertyper.net",
        "https://pointerpointer.com",
        "https://cat-bounce.com",
        "https://theuselessweb.com",
        "https://zoomquilt.org",
    ]

    public var settings: [PrankSetting] {
        [
            .list("urls", "URLs", placeholder: "https://… , https://…",
                  help: "Komma-getrennt. Pro Runde werden zufällige gewählt.",
                  default: .string(Self.defaultURLs.joined(separator: ", "))),
            .intStepper("count", "Tabs pro Runde", min: 1, max: 8, default: .int(1)),
            .slider("interval", "Intervall", min: 5, max: 300, step: 5, unit: "s", default: .double(20)),
            .choice("browser", "Browser", [
                .init("default", "Standard-Browser"),
                .init("Safari", "Safari"),
                .init("Google Chrome", "Chrome"),
            ], default: .string("default")),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.tabflood")

    public init() {}

    public func run(context: PrankContext) throws {
        let interval = context.config.double(id, "interval", 20)
        timer.start(interval: interval) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        let urls = context.config.list(id, "urls", Self.defaultURLs)
        let count = max(1, context.config.int(id, "count", 1))
        let browser = context.config.string(id, "browser", "default")
        for _ in 0..<count {
            guard let url = urls.randomElement() else { return }
            if browser == "default" {
                _ = try? context.runner.shell("/usr/bin/open", [url])
            } else {
                _ = try? context.runner.shell("/usr/bin/open", ["-a", browser, url])
            }
        }
    }
}

/// Periodically reloads the active browser tab — the page keeps "refreshing
/// itself". Reversible: undo stops the timer.
public final class AutoRefreshPrank: PrankModule {
    public let id = "autoRefresh"
    public let name = "Auto-Neuladen"
    public let summary = "Lädt den aktiven Tab in Safari/Chrome in Abständen neu."
    public let category = PrankCategory.browser
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = [.automation]
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("interval", "Intervall", min: 3, max: 120, step: 1, unit: "s", default: .double(15)),
            .slider("probability", "Wahrscheinlichkeit", min: 0.1, max: 1.0, step: 0.1,
                    help: "Chance pro Intervall, dass neu geladen wird.", default: .double(0.7)),
        ]
    }

    private let timer = RepeatingTimer(label: "loki.autorefresh")

    public init() {}

    public func run(context: PrankContext) throws {
        let interval = context.config.double(id, "interval", 15)
        timer.start(interval: interval) { [weak self] in self?.fire(context: context) }
    }

    public func undo(context: PrankContext) throws { timer.stop() }

    private func fire(context: PrankContext) {
        let probability = context.config.double(id, "probability", 0.7)
        guard Double.random(in: 0..<1) < probability else { return }
        let frontApp = (try? context.runner.appleScript(
            "tell application \"System Events\" to get name of first application process whose frontmost is true"
        )) ?? ""
        switch frontApp {
        case "Safari":
            _ = try? context.runner.appleScript(
                "tell application \"Safari\" to set URL of current tab of front window to (URL of current tab of front window)")
        case "Google Chrome":
            _ = try? context.runner.appleScript(
                "tell application \"Google Chrome\" to reload active tab of front window")
        default:
            break
        }
    }
}
