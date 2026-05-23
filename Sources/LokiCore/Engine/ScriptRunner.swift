import Foundation

public extension String {
    /// Escape a string for safe interpolation into an AppleScript double-quoted
    /// literal (backslashes and quotes).
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

public enum ScriptError: Error, LocalizedError {
    case appleScript(String)
    case shell(code: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case .appleScript(let msg): return "AppleScript-Fehler: \(msg)"
        case .shell(let code, let stderr): return "Shell-Fehler (\(code)): \(stderr)"
        }
    }
}

/// Runs AppleScript and shell commands for pranks. AppleScript goes through
/// `osascript` so it works identically whether Loki runs as a bare binary or a
/// bundled .app, and so failures surface as readable stderr.
public final class ScriptRunner {

    public init() {}

    /// Run an AppleScript source string and return its (trimmed) stdout.
    @discardableResult
    public func appleScript(_ source: String) throws -> String {
        do {
            return try shell("/usr/bin/osascript", ["-e", source])
        } catch let ScriptError.shell(_, stderr) {
            throw ScriptError.appleScript(stderr)
        }
    }

    /// Run an executable with arguments. Throws on non-zero exit.
    @discardableResult
    public func shell(_ launchPath: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ScriptError.shell(code: process.terminationStatus,
                                    stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
