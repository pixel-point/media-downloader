import Foundation

struct DependencyStatus: Equatable {
    let missingTools: [String]

    var isSatisfied: Bool {
        missingTools.isEmpty
    }
}

enum DependencyChecker {
    static let installPrompt = "Install ffmpeg and yt-dlp on macOS. Prefer Homebrew if available. Verify both commands work: ffmpeg -version and yt-dlp --version."

    static func check() -> DependencyStatus {
        let missing = ["ffmpeg", "yt-dlp"].filter { executablePath(named: $0) == nil }
        return DependencyStatus(missingTools: missing)
    }

    static func executablePath(named tool: String) -> String? {
        let fileManager = FileManager.default

        for directory in searchDirectories {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(tool).path
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    static var processEnvironment: [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = searchDirectories.joined(separator: ":")
        return environment
    }

    static func javaScriptRuntimeArgument() -> [String]? {
        if let nodePath = executablePath(named: "node") {
            return ["--js-runtimes", "node:\(nodePath)"]
        }

        if let denoPath = executablePath(named: "deno") {
            return ["--js-runtimes", "deno:\(denoPath)"]
        }

        if let bunPath = executablePath(named: "bun") {
            return ["--js-runtimes", "bun:\(bunPath)"]
        }

        return nil
    }

    private static var searchDirectories: [String] {
        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let homeDirectory = NSHomeDirectory()
        let commonDirectories = [
            URL(fileURLWithPath: homeDirectory, isDirectory: true)
                .appendingPathComponent(".local/bin", isDirectory: true)
                .path,
            URL(fileURLWithPath: homeDirectory, isDirectory: true)
                .appendingPathComponent("bin", isDirectory: true)
                .path,
            "/Applications/Codex.app/Contents/Resources",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/opt/local/bin",
            "/usr/bin",
            "/bin"
        ]

        var result: [String] = []
        for directory in pathDirectories + commonDirectories where !directory.isEmpty && !result.contains(directory) {
            result.append(directory)
        }
        return result
    }
}
