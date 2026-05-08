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

    func exportTrim(
        sourceURL: URL,
        selection: TrimSelection,
        to outputURL: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        guard selection.end - selection.start >= 0.25 else {
            throw TrimExportError.invalidRange
        }

        try? fileManager.removeItem(at: outputURL)
        try fileManager.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let arguments = Self.exportArguments(sourceURL: sourceURL, selection: selection, outputURL: outputURL)

        try await runProcess(
            executable: "/usr/bin/env",
            arguments: arguments,
            expectedDuration: selection.end - selection.start,
            onProgress: onProgress
        )
        return outputURL
    }

    nonisolated static func exportArguments(sourceURL: URL, selection: TrimSelection, outputURL: URL) -> [String] {
        [
            "ffmpeg",
            "-y",
            "-progress", "pipe:1",
            "-nostats",
            "-i", sourceURL.path,
            "-ss", formatTime(selection.start),
            "-t", formatTime(selection.end - selection.start),
            "-map", "0:v:0",
            "-map", "0:a?",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-crf", "18",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            outputURL.path
        ]
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

    private nonisolated static func formatTime(_ seconds: Double) -> String {
        String(format: "%.3f", seconds)
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        expectedDuration: Double,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let capture = TrimProcessCapture(expectedDuration: expectedDuration, onProgress: onProgress)

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = DependencyChecker.processEnvironment
            process.standardOutput = stdout
            process.standardError = stderr

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                    return
                }

                capture.appendProgressChunk(chunk)
            }

            process.terminationHandler = { process in
                stdout.fileHandleForReading.readabilityHandler = nil
                let remainingProgressData = stdout.fileHandleForReading.readDataToEndOfFile()
                if !remainingProgressData.isEmpty, let chunk = String(data: remainingProgressData, encoding: .utf8) {
                    capture.appendProgressChunk(chunk)
                }

                capture.finish()
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

private final class TrimProcessCapture {
    private let queue = DispatchQueue(label: "TrimExportService.Progress")
    private let expectedDuration: Double
    private let onProgress: (@Sendable (Double) -> Void)?
    private var buffer = ""
    private var latestProgress: Double = 0

    init(expectedDuration: Double, onProgress: (@Sendable (Double) -> Void)?) {
        self.expectedDuration = max(expectedDuration, 0.001)
        self.onProgress = onProgress
    }

    func appendProgressChunk(_ chunk: String) {
        queue.sync {
            buffer += chunk

            while let newlineRange = buffer.rangeOfCharacter(from: .newlines) {
                let line = String(buffer[..<newlineRange.lowerBound])
                buffer.removeSubrange(..<newlineRange.upperBound)
                handle(line: line)
            }
        }
    }

    func finish() {
        queue.sync {
            if !buffer.isEmpty {
                handle(line: buffer)
                buffer.removeAll()
            }

            latestProgress = 100
            onProgress?(100)
        }
    }

    private func handle(line: String) {
        let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }

        if parts[0] == "out_time_ms", let outTimeMs = Double(parts[1]) {
            let seconds = outTimeMs / 1_000_000
            let progress = max(0, min((seconds / expectedDuration) * 100, 100))
            guard abs(progress - latestProgress) >= 0.5 || progress == 100 else { return }
            latestProgress = progress
            onProgress?(progress)
        }
    }
}
