@testable import MediaDownloader
import XCTest

final class PreferencesStoreTests: XCTestCase {
    func testDefaultDownloadFolderIsSystemDownloadsFolder() {
        let suiteName = "PreferencesStoreTests.default.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        let expected = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads", isDirectory: true)

        XCTAssertEqual(store.downloadFolder.standardizedFileURL.path, expected.standardizedFileURL.path)
        XCTAssertFalse(store.downloadFolder.lastPathComponent == "Media Downloader")
    }

    func testCustomDownloadFolderPersists() {
        let suiteName = "PreferencesStoreTests.custom.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)
        let customURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MediaDownloaderCustom", isDirectory: true)

        store.downloadFolder = customURL

        XCTAssertEqual(store.downloadFolder.standardizedFileURL.path, customURL.standardizedFileURL.path)
    }

    func testDownloadQualityDefaultsToAutomatic() {
        let suiteName = "PreferencesStoreTests.qualityDefault.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)

        XCTAssertEqual(store.downloadQuality, .automatic)
    }

    func testDownloadQualityPersists() {
        let suiteName = "PreferencesStoreTests.qualityPersist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = PreferencesStore(defaults: defaults)

        store.downloadQuality = .p2160

        XCTAssertEqual(store.downloadQuality, .p2160)
    }
}
