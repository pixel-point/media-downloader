@testable import MediaDownloader
import Foundation
import XCTest

final class DependencyCheckerTests: XCTestCase {
    func testCheckDetectsInstalledAndMissingToolsAndHomebrew() throws {
        let sandbox = try makeSandbox()
        defer { try? FileManager.default.removeItem(at: sandbox) }

        try makeExecutable(named: "ffmpeg", in: sandbox)
        try makeExecutable(named: "brew", in: sandbox)

        let status = DependencyChecker.check(
            environment: ["PATH": sandbox.path],
            extraSearchDirectories: []
        )

        XCTAssertEqual(status.installedTools.map(\.executableName), ["ffmpeg"])
        XCTAssertEqual(status.missingTools.map(\.executableName), ["yt-dlp"])
        XCTAssertTrue(status.hasHomebrew)
        XCTAssertEqual(status.installCommand, "brew install yt-dlp")
    }

    func testInstallPromptFallsBackToHomebrewBootstrapWhenMissing() {
        let status = DependencyChecker.check(
            environment: ["PATH": "/tmp/definitely-missing-tools"],
            extraSearchDirectories: []
        )

        let prompt = DependencyChecker.installPrompt(for: status)

        XCTAssertTrue(prompt.contains("https://brew.sh"))
        XCTAssertTrue(prompt.contains("brew install ffmpeg yt-dlp"))
        XCTAssertTrue(prompt.contains("ffmpeg -version"))
        XCTAssertTrue(prompt.contains("yt-dlp --version"))
    }

    private func makeSandbox() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeExecutable(named name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name)
        let data = Data("#!/bin/sh\nexit 0\n".utf8)
        FileManager.default.createFile(atPath: url.path, contents: data)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: url.path
        )
    }
}
