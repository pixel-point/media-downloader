import Foundation

enum TrimExportError: LocalizedError {
    case invalidRange
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidRange:
            return "Choose a longer trim range."
        case .processFailed(let message):
            return message.isEmpty ? "Trim export failed." : message
        }
    }
}

actor TrimExportService {
    private let fileManager = FileManager.default

    func exportTrim(sourceURL: URL, selection: TrimSelection, to outputURL: URL) async throws -> URL {
        guard selection.end - selection.start >= 0.25 else {
            throw TrimExportError.invalidRange
        }

        try? fileManager.removeItem(at: outputURL)
        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let arguments = [
            "ffmpeg",
            "-y",
            "-ss", formatTime(selection.start),
            "-i", sourceURL.path,
            "-t", formatTime(selection.end - selection.start),
            "-c", "copy",
            "-movflags", "+faststart",
            outputURL.path
        ]

        try await runProcess(executable: "/usr/bin/env", arguments: arguments)
        return outputURL
    }

    func saveURL(for sourceURL: URL, selection: TrimSelection) -> URL {
        let folder = sourceURL.deletingLastPathComponent()
        let name = sourceURL.deletingPathExtension().lastPathComponent
        let start = Int(selection.start.rounded())
        let end = Int(selection.end.rounded())
        return folder
            .appendingPathComponent("\(name) trim \(start)-\(end)s")
            .appendingPathExtension("mp4")
    }

    func temporaryURL(for sourceURL: URL) throws -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let directory = support.appendingPathComponent("MediaDownloader/TrimExports", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
    }

    private func formatTime(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }

    private func runProcess(executable: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = DependencyChecker.processEnvironment
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { process in
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                let error = String(data: errorData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TrimExportError.processFailed(error))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
