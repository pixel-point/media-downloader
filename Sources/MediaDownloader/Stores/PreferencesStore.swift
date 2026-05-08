import Foundation

final class PreferencesStore {
    private let downloadFolderKey = "downloadFolderPath"
    private let downloadQualityKey = "downloadQuality"
    private let hotKeyPrefix = "hotKeyShortcut."
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var downloadFolder: URL {
        get {
            if let path = defaults.string(forKey: downloadFolderKey), !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }

            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            return downloads
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)
        }
        set {
            defaults.set(newValue.path, forKey: downloadFolderKey)
        }
    }

    var downloadQuality: DownloadQuality {
        get {
            guard let rawValue = defaults.string(forKey: downloadQualityKey),
                  let quality = DownloadQuality(rawValue: rawValue) else {
                return .defaultValue
            }

            return quality
        }
        set {
            defaults.set(newValue.rawValue, forKey: downloadQualityKey)
        }
    }

    func hotKeyShortcut(for action: HotKeyAction) -> HotKeyShortcut {
        let key = hotKeyKey(for: action)
        guard let data = defaults.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(HotKeyShortcut.self, from: data) else {
            return action.defaultShortcut
        }

        return shortcut
    }

    func setHotKeyShortcut(_ shortcut: HotKeyShortcut, for action: HotKeyAction) {
        let key = hotKeyKey(for: action)
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: .mediaDownloaderHotKeysDidChange, object: action)
    }

    private func hotKeyKey(for action: HotKeyAction) -> String {
        hotKeyPrefix + action.rawValue
    }
}
