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

    private static var searchDirectories: [String] {
        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        let commonDirectories = [
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
