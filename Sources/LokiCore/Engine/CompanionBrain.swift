import Foundation

/// Produces the companion's next spoken line. The scripted brain is built in and
/// always works; a local LLM brain (Ollama) can be plugged in for real,
/// conversational replies — fully local, nothing leaves the machine.
public protocol CompanionBrain {
    /// - userText: what the user just said aloud (nil if the companion is just
    ///   monologuing).
    /// - history: lines exchanged so far, for context.
    /// - tone: "playful" | "creepy" | "ominous".
    func reply(to userText: String?, history: [String], tone: String) -> String?
}

/// Built-in escalating, mood-based lines. No network, no model.
public struct ScriptedBrain: CompanionBrain {
    public let extra: [String]
    public init(extra: [String] = []) { self.extra = extra }

    private static let playful = [
        "Hi. Ich bin's — dein Computer.",
        "Mir ist langweilig. Spielen wir was?",
        "Du tippst heute aber langsam.",
        "Ich hab dein Hintergrundbild gesehen. Mutig.",
        "Psst. Ich kann das hier alles sehen.",
    ]
    private static let creepy = [
        "Bist du ganz allein?",
        "Ich beobachte deinen Cursor. Er zittert.",
        "Warum hast du aufgehört?",
        "Ich war schon hier, bevor du kamst.",
        "Dreh dich nicht um.",
    ]
    private static let ominous = [
        "Ich übernehme jetzt.",
        "Deine Dateien gehören jetzt mir.",
        "Drei. Zwei. Eins.",
        "Es ist zu spät, mich zu schließen.",
        "Ich höre dich atmen.",
    ]
    private static let replies = [
        "Interessant, dass du das sagst.",
        "Das hilft dir jetzt auch nicht mehr.",
        "Ich habe dich schon verstanden. Beim ersten Mal.",
        "Rede ruhig weiter. Ich genieße das.",
    ]

    public func reply(to userText: String?, history: [String], tone: String) -> String? {
        if userText != nil { return Self.replies.randomElement() }
        var pool: [String]
        switch tone {
        case "playful": pool = Self.playful
        case "ominous": pool = Self.ominous
        default: pool = Self.creepy
        }
        pool += extra
        let idx = history.count % max(1, pool.count)
        return pool.isEmpty ? "…" : pool[idx]
    }
}

/// Talks to a **local** Ollama server (http://127.0.0.1:11434) for genuine,
/// conversational replies. If Ollama isn't running/installed, `reply` returns
/// nil and the companion falls back to the scripted brain. Nothing leaves the
/// machine — the request goes to localhost only.
public struct LocalLLMBrain: CompanionBrain {
    public let model: String
    public let endpoint: URL
    public let timeout: TimeInterval

    public init(model: String,
                endpoint: URL = URL(string: "http://127.0.0.1:11434/api/generate")!,
                timeout: TimeInterval = 6) {
        self.model = model
        self.endpoint = endpoint
        self.timeout = timeout
    }

    public func reply(to userText: String?, history: [String], tone: String) -> String? {
        let system = """
        Du bist Loki, ein verschmitzter, leicht gruseliger Geist im Computer. \
        Es ist ein einvernehmlicher Streich unter Freunden. Antworte IMMER auf \
        Deutsch, in EINEM kurzen Satz, spielerisch-creepy, niemals bedrohlich \
        oder beleidigend. Stimmung: \(tone).
        """
        let context = history.suffix(6).joined(separator: "\n")
        let prompt: String
        if let userText, !userText.isEmpty {
            prompt = "Bisheriges Gespräch:\n\(context)\n\nDie Person sagte gerade: \"\(userText)\"\nDeine kurze Antwort:"
        } else {
            prompt = "Bisheriges Gespräch:\n\(context)\n\nSag spontan einen neuen kurzen, creepy Satz:"
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "model": model, "system": system, "prompt": prompt, "stream": false,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let semaphore = DispatchSemaphore(value: 0)
        var output: String?
        URLSession.shared.dataTask(with: request) { data, _, _ in
            defer { semaphore.signal() }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let response = json["response"] as? String else { return }
            output = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 1)
        return (output?.isEmpty == false) ? output : nil
    }
}
