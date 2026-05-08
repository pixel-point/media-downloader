import Foundation

struct ActiveTrimSession: Identifiable, Equatable {
    enum ExportStrategy: Equatable {
        case localFile(URL)
        case youtubeSectionDownload
    }

    let id = UUID()
    let historyItemID: DownloadItem.ID?
    let sourceURL: String
    let title: String
    let previewURL: URL
    let exportStrategy: ExportStrategy

    init(item: DownloadItem) {
        let fileURL = URL(fileURLWithPath: item.filePath)
        self.historyItemID = item.id
        self.sourceURL = item.sourceURL
        self.title = item.displayName
        self.previewURL = fileURL
        self.exportStrategy = .localFile(fileURL)
    }

    init(youtubeSourceURL: String, title: String, previewURL: URL) {
        self.historyItemID = nil
        self.sourceURL = youtubeSourceURL
        self.title = title
        self.previewURL = previewURL
        self.exportStrategy = .youtubeSectionDownload
    }

    var fileURL: URL? {
        guard case .localFile(let url) = exportStrategy else {
            return nil
        }

        return url
    }

    var usesRemotePreview: Bool {
        fileURL == nil
    }
}
