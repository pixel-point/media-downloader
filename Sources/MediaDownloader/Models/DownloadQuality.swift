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
            return nil
        case .p720:
            return "bv*[height<=720]+ba/b[height<=720]"
        case .p1080:
            return "bv*[height<=1080]+ba/b[height<=1080]"
        case .p1440:
            return "bv*[height<=1440]+ba/b[height<=1440]"
        case .p2160:
            return "bv*[height<=2160]+ba/b[height<=2160]"
        }
    }

    static let defaultValue: Self = .automatic
}
