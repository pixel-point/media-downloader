import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var inputText = ""
    @Published private(set) var history: [DownloadItem] = []
    @Published private(set) var isDownloading = false
    @Published var statusMessage: String?
    @Published var activeTrimSession: ActiveTrimSession?

    private let preferences = PreferencesStore()
    private let historyStore = HistoryStore()
    private let downloader = MediaDownloaderService()
    private let thumbnailGenerator = ThumbnailGenerator()
    private let trimExporter = TrimExportService()
    private var pasteTask: Task<Void, Never>?

    var downloadFolderPath: String {
        preferences.downloadFolder.path
    }

    init() {
        history = historyStore.load()
    }

    func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = preferences.downloadFolder
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        preferences.downloadFolder = url
    }

    func handlePasteCandidate() {
        pasteTask?.cancel()

        let candidate = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard URLValidator.looksLikeWebURL(candidate) else {
            return
        }

        pasteTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.startDownloadIfNeeded(candidate)
        }
    }

    func submitInput() {
        pasteTask?.cancel()
        Task { [weak self] in
            guard let self else { return }
            await self.startDownloadIfNeeded(self.inputText)
        }
    }

    func copyFile(_ item: DownloadItem) {
        ClipboardService.copyFile(URL(fileURLWithPath: item.filePath))
        statusMessage = "Copied \(item.displayName)."
    }

    func revealInFinder(_ item: DownloadItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.filePath)])
    }

    func openSourceURL(_ item: DownloadItem) {
        guard let url = URL(string: item.sourceURL) else { return }
        NSWorkspace.shared.open(url)
    }

    func deleteHistoryItem(_ item: DownloadItem) {
        history.removeAll { $0.id == item.id }
        historyStore.save(history)

        if activeTrimSession?.item.id == item.id {
            activeTrimSession = nil
        }
    }

    func editTrim(_ item: DownloadItem) {
        activeTrimSession = ActiveTrimSession(item: item)
    }

    func closeTrim() {
        activeTrimSession = nil
    }

    func saveActiveTrim(_ selection: TrimSelection) async throws -> URL {
        guard let session = activeTrimSession else {
            throw TrimExportError.invalidRange
        }

        let outputURL = await trimExporter.saveURL(for: session.fileURL, selection: selection)
        return try await trimExporter.exportTrim(
            sourceURL: session.fileURL,
            selection: selection,
            to: outputURL
        )
    }

    func copyActiveTrim(_ selection: TrimSelection) async throws {
        guard let session = activeTrimSession else {
            throw TrimExportError.invalidRange
        }

        let outputURL = try await trimExporter.temporaryURL(for: session.fileURL)
        let trimmedURL = try await trimExporter.exportTrim(
            sourceURL: session.fileURL,
            selection: selection,
            to: outputURL
        )
        ClipboardService.copyFile(trimmedURL)
    }

    private func startDownloadIfNeeded(_ rawURL: String) async {
        let sourceURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isDownloading else { return }
        guard URLValidator.looksLikeWebURL(sourceURL) else {
            statusMessage = "Enter a valid URL."
            return
        }

        isDownloading = true
        statusMessage = "Downloading..."

        do {
            let result = try await downloader.download(sourceURL: sourceURL, destinationFolder: preferences.downloadFolder)
            let thumbnailPath = try? await thumbnailGenerator.thumbnailPath(for: result.fileURL)
            let item = DownloadItem(
                sourceURL: sourceURL,
                title: result.title,
                filePath: result.fileURL.path,
                thumbnailPath: thumbnailPath?.path,
                createdAt: Date()
            )

            history.insert(item, at: 0)
            historyStore.save(history)
            ClipboardService.copyFile(result.fileURL)
            activeTrimSession = ActiveTrimSession(item: item)
            inputText = ""
            statusMessage = "Downloaded and copied."
        } catch {
            statusMessage = error.localizedDescription
        }

        isDownloading = false
    }
}
