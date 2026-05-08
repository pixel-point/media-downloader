import Foundation

enum MediaDownloaderError: LocalizedError {
    case missingTool(String)
    case processFailed(String)
    case missingOutputFile

    var errorDescription: String? {
        switch self {
        case .missingTool(let tool):
            return "\(tool) was not found in PATH."
        case .processFailed(let message):
            return message.isEmpty ? "Download failed." : message
        case .missingOutputFile:
            return "Download finished but no output file was found."
        }
    }
}

actor MediaDownloaderService {
    private let fileManager = FileManager.default
    private static let progressPrefix = "__MD_PROGRESS__"

    func download(
        sourceURL: String,
        destinationFolder: URL,
        quality: DownloadQuality,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> DownloadResult {
        try await requireTool("yt-dlp")
        try await requireTool("ffmpeg")
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let startDate = Date()
        let arguments = Self.downloadArguments(
            sourceURL: sourceURL,
            destinationFolder: destinationFolder,
            quality: quality
        )

        let output = try await runProcess(executable: "/usr/bin/env", arguments: arguments) { line in
            guard let progress = Self.progressValue(from: line) else {
                return
            }

            onProgress?(progress)
        }

        let lines = output.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let filePath = lines.first(where: { $0.hasPrefix("/") && fileManager.fileExists(atPath: $0) })
        let fileURL = try filePath.map(URL.init(fileURLWithPath:)) ?? newestMediaFile(in: destinationFolder, after: startDate)
        let title = lines.last(where: { !$0.hasPrefix("/") }) ?? fileURL.deletingPathExtension().lastPathComponent
        return DownloadResult(fileURL: fileURL, title: title)
    }

    static func downloadArguments(sourceURL: String, destinationFolder: URL, quality: DownloadQuality) -> [String] {
        var arguments = [
            "yt-dlp",
            "--no-playlist",
            "--newline",
            "--progress-template", "download:\(progressPrefix)%(progress._percent_str)s",
            "--restrict-filenames",
            "--merge-output-format", "mp4",
            "--recode-video", "mp4",
            "--paths", destinationFolder.path,
            "--output", "%(title).180B [%(id)s].%(ext)s",
            "--print", "after_move:%(filepath)s",
            "--print", "after_move:%(title)s"
        ]

        if let formatSelector = quality.formatSelector {
            arguments.append(contentsOf: ["-f", formatSelector])
        }

        if let javaScriptRuntimeArgument = DependencyChecker.javaScriptRuntimeArgument() {
            arguments.append(contentsOf: javaScriptRuntimeArgument)
        }

        arguments.append(sourceURL)
        return arguments
    }

    static func progressValue(from line: String) -> Double? {
        guard line.hasPrefix(progressPrefix) else {
            return nil
        }

        let rawValue = line.dropFirst(progressPrefix.count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")

        guard let percent = Double(rawValue) else {
            return nil
        }

        return max(0, min(percent, 100))
    }

    private func requireTool(_ tool: String) async throws {
        _ = try await runProcess(executable: "/usr/bin/env", arguments: ["which", tool])
    }

    private func newestMediaFile(in folder: URL, after date: Date) throws -> URL {
        let extensions = Set(["mp4", "m4v", "mov"])
        let files = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let candidates = files.compactMap { url -> (URL, Date)? in
            guard extensions.contains(url.pathExtension.lowercased()) else {
                return nil
            }

            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate, modified >= date.addingTimeInterval(-2) else {
                return nil
            }

            return (url, modified)
        }

        guard let newest = candidates.max(by: { $0.1 < $1.1 })?.0 else {
            throw MediaDownloaderError.missingOutputFile
        }

        return newest
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        onLine: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> ProcessOutput {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let capture = ProcessCapture(onLine: onLine)

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = DependencyChecker.processEnvironment
            process.standardOutput = stdout
            process.standardError = stderr

            let consumeData: @Sendable (Data, Bool) -> Void = { data, isStdout in
                guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                    return
                }

                capture.append(chunk, isStdout: isStdout)
            }

            stdout.fileHandleForReading.readabilityHandler = { handle in
                consumeData(handle.availableData, true)
            }

            stderr.fileHandleForReading.readabilityHandler = { handle in
                consumeData(handle.availableData, false)
            }

            process.terminationHandler = { process in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                consumeData(stdout.fileHandleForReading.readDataToEndOfFile(), true)
                consumeData(stderr.fileHandleForReading.readDataToEndOfFile(), false)
                let output = capture.finish()

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: MediaDownloaderError.processFailed(output.stderr))
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

private struct ProcessOutput {
    let stdout: String
    let stderr: String
}

private final class ProcessCapture {
    private let queue = DispatchQueue(label: "MediaDownloaderService.ProcessOutput")
    private let onLine: @Sendable (String) -> Void
    private var stdoutOutput = ""
    private var stderrOutput = ""
    private var stdoutBuffer = ""
    private var stderrBuffer = ""

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ chunk: String, isStdout: Bool) {
        queue.sync {
            if isStdout {
                stdoutOutput += chunk
                stdoutBuffer += chunk
                emitCompletedLines(from: &stdoutBuffer)
            } else {
                stderrOutput += chunk
                stderrBuffer += chunk
                emitCompletedLines(from: &stderrBuffer)
            }
        }
    }

    func finish() -> ProcessOutput {
        queue.sync {
            if !stdoutBuffer.isEmpty {
                onLine(stdoutBuffer)
                stdoutBuffer.removeAll()
            }

            if !stderrBuffer.isEmpty {
                onLine(stderrBuffer)
                stderrBuffer.removeAll()
            }

            return ProcessOutput(stdout: stdoutOutput, stderr: stderrOutput)
        }
    }

    private func emitCompletedLines(from buffer: inout String) {
        while let newlineRange = buffer.rangeOfCharacter(from: .newlines) {
            let line = String(buffer[..<newlineRange.lowerBound])
            onLine(line)
            buffer.removeSubrange(..<newlineRange.upperBound)
        }
    }
}
