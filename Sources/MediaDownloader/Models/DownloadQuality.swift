import Foundation

enum DownloadQuality: String, CaseIterable, Codable {
    case automatic
    case p720
    case p1080
    case p1440
    case p2160

    var title: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .p720:
            return "720p"
        case .p1080:
            return "1080p"
        case .p1440:
            return "1440p"
        case .p2160:
            return "4K"
        }
    }

    var formatSelector: String? {
        switch self {
        case .automatic:
            return "bv*+ba/b"
        case .p720:
            return exactResolutionSelector(primaryHeight: 720, fallbacks: [480, 360, 240, 144])
        case .p1080:
            return exactResolutionSelector(primaryHeight: 1080, fallbacks: [720, 480, 360, 240, 144])
        case .p1440:
            return exactResolutionSelector(primaryHeight: 1440, fallbacks: [1080, 720, 480, 360, 240, 144])
        case .p2160:
            return exactResolutionSelector(primaryHeight: 2160, fallbacks: [1440, 1080, 720, 480, 360, 240, 144])
        }
    }

    static let defaultValue: Self = .automatic

    private func exactResolutionSelector(primaryHeight: Int, fallbacks: [Int]) -> String {
        let candidates = ([primaryHeight] + fallbacks).map { "bv*[height=\($0)]+ba" }
        let progressiveFallback = "b[height<=\(primaryHeight)]"
        return "(" + (candidates + [progressiveFallback]).joined(separator: "/") + ")"
    }
}
