import Foundation

struct ToolDependency: Equatable, Identifiable {
    let executableName: String
    let displayName: String

    var id: String {
        executableName
    }
}

struct DependencyStatus: Equatable {
    let requiredTools: [ToolDependency]
    let installedTools: [ToolDependency]
    let missingTools: [ToolDependency]
    let homebrewPath: String?

    var isSatisfied: Bool {
        missingTools.isEmpty
    }

    var hasHomebrew: Bool {
        homebrewPath != nil
    }

    var missingToolNames: String {
        Self.joinedNames(for: missingTools)
    }

    var installCommand: String? {
        guard hasHomebrew, !missingTools.isEmpty else { return nil }
        return "brew install \(missingTools.map(\.executableName).joined(separator: " "))"
    }

    private static func joinedNames(for tools: [ToolDependency]) -> String {
        switch tools.map(\.displayName) {
        case []:
            return ""
        case let names where names.count == 1:
            return names[0]
        case let names where names.count == 2:
            return "\(names[0]) and \(names[1])"
        case let names:
            return "\(names.dropLast().joined(separator: ", ")), and \(names.last!)"
        }
    }
}

enum DependencyChecker {
    static let requiredTools = [
        ToolDependency(executableName: "ffmpeg", displayName: "FFmpeg"),
        ToolDependency(executableName: "yt-dlp", displayName: "yt-dlp")
    ]
    static let homebrewInstallURL = URL(string: "https://brew.sh")!

    static func installPrompt(for status: DependencyStatus) -> String {
        guard !status.isSatisfied else {
            return "ffmpeg and yt-dlp are already installed."
        }

        let verifyCommands = status.missingTools
            .map(verifyCommand(for:))
            .joined(separator: " and ")

        if let installCommand = status.installCommand {
            return """
            Install the missing dependency \(status.missingToolNames) with Homebrew:
            \(installCommand)

            Then verify it works:
            \(verifyCommands)
            """
        }

        return """
        Install Homebrew from \(homebrewInstallURL.absoluteString), then install the missing dependency \(status.missingToolNames):
        brew install \(status.missingTools.map(\.executableName).joined(separator: " "))

        Then verify it works:
        \(verifyCommands)
        """
    }

    static func check(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        extraSearchDirectories: [String] = commonDirectories
    ) -> DependencyStatus {
        let installed = requiredTools.filter {
            executablePath(
                named: $0.executableName,
                environment: environment,
                extraSearchDirectories: extraSearchDirectories
            ) != nil
        }
        let missing = requiredTools.filter { tool in
            installed.contains(where: { $0.executableName == tool.executableName }) == false
        }
        let homebrewPath = executablePath(
            named: "brew",
            environment: environment,
            extraSearchDirectories: extraSearchDirectories
        )
        return DependencyStatus(
            requiredTools: requiredTools,
            installedTools: installed,
            missingTools: missing,
            homebrewPath: homebrewPath
        )
    }

    static func executablePath(
        named tool: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        extraSearchDirectories: [String] = commonDirectories
    ) -> String? {
        let fileManager = FileManager.default

        for directory in searchDirectories(in: environment, extraSearchDirectories: extraSearchDirectories) {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(tool).path
            if fileManager.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    static var processEnvironment: [String: String] {
        processEnvironment(from: ProcessInfo.processInfo.environment)
    }

    static func processEnvironment(
        from environment: [String: String],
        extraSearchDirectories: [String] = commonDirectories
    ) -> [String: String] {
        var result = environment
        result["PATH"] = searchDirectories(in: environment, extraSearchDirectories: extraSearchDirectories).joined(separator: ":")
        return result
    }

    private static func verifyCommand(for tool: ToolDependency) -> String {
        switch tool.executableName {
        case "ffmpeg":
            return "ffmpeg -version"
        default:
            return "\(tool.executableName) --version"
        }
    }

    private static func searchDirectories(
        in environment: [String: String],
        extraSearchDirectories: [String]
    ) -> [String] {
        let pathDirectories = (environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        var result: [String] = []
        for directory in pathDirectories + extraSearchDirectories where !directory.isEmpty && !result.contains(directory) {
            result.append(directory)
        }
        return result
    }

    private static let commonDirectories = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/opt/local/bin",
        "/usr/bin",
        "/bin"
    ]
}
