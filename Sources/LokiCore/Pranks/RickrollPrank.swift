import Foundation

/// Polls the frontmost browser tab and, with a configurable probability,
/// redirects it to a Rickroll video — producing the "every website turns into a
/// Rickroll" effect. Reversible: undo just stops the poller. Nothing about the
/// browser is permanently changed.
public final class RickrollPrank: PrankModule {
    public let id = "rickroll"
    public let name = "Rickroll-Redirect"
    public let summary = "Leitet zufällige Tabs in Safari/Chrome auf ein Rickroll-Video um."
    public let category = PrankCategory.browser
    public let intensity = Intensity.silly
    public let requiredPermissions: [Permission] = [.automation]
    public let isReversible = true

    public var settings: [PrankSetting] {
        [
            .slider("probability", "Wahrscheinlichkeit", min: 0.05, max: 1.0, step: 0.05, unit: "",
                    help: "Chance pro Prüfung, dass der Tab umgeleitet wird.", default: .double(0.3)),
            .slider("interval", "Prüf-Intervall", min: 1, max: 30, step: 1, unit: "s",
                    help: "Wie oft der aktive Tab geprüft wird.", default: .double(4)),
            .text("url", "Ziel-URL", placeholder: "https://…",
                  help: "Wohin umgeleitet wird.", default: .string(Self.rickrollURL)),
            .toggle("safari", "Safari einbeziehen", default: .bool(true)),
            .toggle("chrome", "Chrome einbeziehen", default: .bool(true)),
        ]
    }

    private static let rickrollURL = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "loki.rickroll")
    private var targetURL = rickrollURL
    private var includeSafari = true
    private var includeChrome = true
    /// Remember the last URL we redirected so we don't fight the user on every tick.
    private var lastRedirected: String?

    public init() {}

    public func run(context: PrankContext) throws {
        let probability = context.config.double(id, "probability", 0.3)
        let interval = context.config.double(id, "interval", 4)
        queue.sync {
            targetURL = context.config.string(id, "url", Self.rickrollURL)
            includeSafari = context.config.bool(id, "safari", true)
            includeChrome = context.config.bool(id, "chrome", true)
            timer?.cancel()
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + interval, repeating: interval)
            t.setEventHandler { [weak self] in
                self?.tick(context: context, probability: probability)
            }
            t.resume()
            timer = t
        }
    }

    public func undo(context: PrankContext) throws {
        queue.sync {
            timer?.cancel()
            timer = nil
            lastRedirected = nil
        }
    }

    private func tick(context: PrankContext, probability: Double) {
        guard Double.random(in: 0..<1) < probability else { return }
        guard let (browser, currentURL) = frontmostBrowserTab(context: context) else { return }
        // Don't re-redirect the target itself, and don't repeatedly hit the same
        // page (lets the victim navigate away before we strike again).
        guard currentURL != targetURL, currentURL != lastRedirected else { return }
        redirect(browser: browser, context: context)
        lastRedirected = targetURL
    }

    private enum Browser: String { case safari = "Safari", chrome = "Google Chrome" }

    private func frontmostBrowserTab(context: PrankContext) -> (Browser, String)? {
        // Which browser is frontmost?
        let frontApp = (try? context.runner.appleScript(
            "tell application \"System Events\" to get name of first application process whose frontmost is true"
        )) ?? ""

        switch frontApp {
        case "Safari" where includeSafari:
            if let url = try? context.runner.appleScript(
                "tell application \"Safari\" to return URL of current tab of front window"
            ), !url.isEmpty {
                return (.safari, url)
            }
        case "Google Chrome" where includeChrome:
            if let url = try? context.runner.appleScript(
                "tell application \"Google Chrome\" to return URL of active tab of front window"
            ), !url.isEmpty {
                return (.chrome, url)
            }
        default:
            return nil
        }
        return nil
    }

    private func redirect(browser: Browser, context: PrankContext) {
        let script: String
        switch browser {
        case .safari:
            script = "tell application \"Safari\" to set URL of current tab of front window to \"\(targetURL)\""
        case .chrome:
            script = "tell application \"Google Chrome\" to set URL of active tab of front window to \"\(targetURL)\""
        }
        _ = try? context.runner.appleScript(script)
    }
}
