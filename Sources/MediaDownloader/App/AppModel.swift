import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var inputText = ""
    @Published private(set) var history: [DownloadItem] = []
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double?
    @Published var statusMessage: String?
    @Published var activeTrimSession: ActiveTrimSession?
    @Published private(set) var isCheckingForUpdates = false

    private let preferences = PreferencesStore()
    private let historyStore = HistoryStore()
    private let downloader = MediaDownloaderService()
    private let thumbnailGenerator = ThumbnailGenerator()
    private let trimExporter = TrimExportService()
    private let updateChecker = UpdateChecker()
    private var pasteTask: Task<Void, Never>?
    private var didRunAutomaticUpdateCheck = false
    private var settingsWindowController: SettingsWindowController?

    var downloadFolderPath: String {
        preferences.downloadFolder.path
    }

    var downloadQuality: DownloadQuality {
        preferences.downloadQuality
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

    func clearHistory() {
        history.removeAll()
        historyStore.save(history)
        activeTrimSession = nil
    }

    func checkForUpdates(manual: Bool) {
        if !manual {
            guard !didRunAutomaticUpdateCheck else { return }
            didRunAutomaticUpdateCheck = true
        }

        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
                let result = try await updateChecker.check(currentVersion: currentVersion)
                let downloadedUpdate: DownloadedUpdate?

                if case .updateAvailable(let update) = result {
                    downloadedUpdate = try await updateChecker.download(update)
                } else {
                    downloadedUpdate = nil
                }

                await MainActor.run {
                    self.isCheckingForUpdates = false
                    self.presentUpdateResult(
                        result,
                        downloadedUpdate: downloadedUpdate,
                        currentVersion: currentVersion,
                        manual: manual
                    )
                }
            } catch {
                await MainActor.run {
                    self.isCheckingForUpdates = false
                    if manual {
                        self.presentUpdateError(error)
                    }
                }
            }
        }
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                preferences: preferences,
                onCheckForUpdates: { [weak self] in
                    self?.checkForUpdates(manual: true)
                }
            )
        }

        settingsWindowController?.show()
    }

    func hotKeyShortcut(for action: HotKeyAction) -> HotKeyShortcut {
        preferences.hotKeyShortcut(for: action)
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
        downloadProgress = 0
        statusMessage = "Downloading..."

        do {
            let result = try await downloader.download(
                sourceURL: sourceURL,
                destinationFolder: preferences.downloadFolder,
                quality: preferences.downloadQuality,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress = progress
                    }
                }
            )
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

        downloadProgress = nil
        isDownloading = false
    }

    private func presentUpdateResult(
        _ result: UpdateCheckResult,
        downloadedUpdate: DownloadedUpdate?,
        currentVersion: String,
        manual: Bool
    ) {
        switch result {
        case .upToDate:
            guard manual else { return }
            let alert = NSAlert()
            alert.messageText = "MediaDownloader is up to date"
            alert.informativeText = "You are running version \(currentVersion)."
            alert.icon = NSImage(named: NSImage.applicationIconName)
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .updateAvailable(let update):
            let alert = NSAlert()
            alert.messageText = "MediaDownloader \(update.version) is ready"
            alert.informativeText = downloadedUpdate == nil
                ? "A new version is available. You are running \(currentVersion)."
                : "The update has been downloaded in the background. You are running \(currentVersion)."
            alert.icon = NSImage(named: NSImage.applicationIconName)
            alert.addButton(withTitle: "Update")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                if let downloadedUpdate {
                    NSWorkspace.shared.open(downloadedUpdate.fileURL)
                } else {
                    NSWorkspace.shared.open(update.downloadURL ?? update.releaseURL)
                }
            }
        }
    }

    private func presentUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not check for updates"
        alert.informativeText = error.localizedDescription
        alert.icon = NSImage(named: NSImage.applicationIconName)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
