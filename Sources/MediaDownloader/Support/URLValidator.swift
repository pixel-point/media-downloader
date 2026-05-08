import Foundation

enum URLValidator {
    static func looksLikeWebURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }

        guard let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        return components.host?.isEmpty == false
    }

    static func isYouTubeURL(_ value: String) -> Bool {
        guard
            let host = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines))?.host?.lowercased()
        else {
            return false
        }

        let normalized = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return normalized == "youtube.com" || normalized == "m.youtube.com" || normalized == "youtu.be"
    }
}
