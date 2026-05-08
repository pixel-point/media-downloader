@testable import MediaDownloader
import XCTest

final class MediaDownloaderServiceTests: XCTestCase {
    func testAutomaticQualityDoesNotInjectFormatSelector() {
        let destinationFolder = URL(fileURLWithPath: "/tmp/MediaDownloader", isDirectory: true)

        let arguments = MediaDownloaderService.downloadArguments(
            sourceURL: "https://example.com/watch?v=123",
            destinationFolder: destinationFolder,
            quality: .automatic
        )

        XCTAssertEqual(arguments.first, "yt-dlp")
        XCTAssertContainsSequence(arguments, ["-f", "bv*+ba/b"])
        XCTAssertContainsSequence(arguments, ["--progress-template", "download:__MD_PROGRESS__%(progress._percent_str)s"])
        XCTAssertEqual(arguments.last, "https://example.com/watch?v=123")
    }

    func test4KQualityUses2160pSelector() {
        let destinationFolder = URL(fileURLWithPath: "/tmp/MediaDownloader", isDirectory: true)

        let arguments = MediaDownloaderService.downloadArguments(
            sourceURL: "https://example.com/watch?v=123",
            destinationFolder: destinationFolder,
            quality: .p2160
        )

        XCTAssertContainsSequence(arguments, ["-f", "(bv*[height=2160]+ba/bv*[height=1440]+ba/bv*[height=1080]+ba/bv*[height=720]+ba/bv*[height=480]+ba/bv*[height=360]+ba/bv*[height=240]+ba/bv*[height=144]+ba/b[height<=2160])"])
    }

    func test1440QualityPrefersExactHeightBeforeFallbacks() {
        let destinationFolder = URL(fileURLWithPath: "/tmp/MediaDownloader", isDirectory: true)

        let arguments = MediaDownloaderService.downloadArguments(
            sourceURL: "https://example.com/watch?v=123",
            destinationFolder: destinationFolder,
            quality: .p1440
        )

        XCTAssertContainsSequence(arguments, ["-f", "(bv*[height=1440]+ba/bv*[height=1080]+ba/bv*[height=720]+ba/bv*[height=480]+ba/bv*[height=360]+ba/bv*[height=240]+ba/bv*[height=144]+ba/b[height<=1440])"])
    }

    func testProgressLineParsesToNumericPercent() {
        XCTAssertEqual(MediaDownloaderService.progressValue(from: "__MD_PROGRESS__37.5%"), 37.5)
        XCTAssertNil(MediaDownloaderService.progressValue(from: "plain output"))
    }

    func testPreviewArgumentsPreferDirectProgressivePreviewFormats() {
        let arguments = MediaDownloaderService.previewArguments(
            sourceURL: "https://www.youtube.com/watch?v=123",
            quality: .p1440
        )

        XCTAssertContainsSequence(arguments, ["-f", "22/18/b[ext=mp4][height<=720]/b[height<=720]/b"])
        XCTAssertEqual(arguments.last, "https://www.youtube.com/watch?v=123")
    }

    func testSectionDownloadArgumentsIncludeSelectedTimeRange() {
        let arguments = MediaDownloaderService.sectionDownloadArguments(
            sourceURL: "https://www.youtube.com/watch?v=123",
            selection: TrimSelection(start: 2.125, end: 5.75),
            quality: .p1080,
            destinationURL: URL(fileURLWithPath: "/tmp/clip.mp4")
        )

        XCTAssertContainsSequence(arguments, ["--download-sections", "*00:00:02.125-00:00:05.750"])
        XCTAssertContainsSequence(arguments, ["--output", "/tmp/clip.mp4"])
    }

    private func XCTAssertContainsSequence(
        _ arguments: [String],
        _ expected: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !expected.isEmpty, expected.count <= arguments.count else {
            XCTFail("Invalid expected sequence", file: file, line: line)
            return
        }

        let contains = arguments.indices.contains { index in
            let end = index + expected.count
            guard end <= arguments.count else { return false }
            return Array(arguments[index..<end]) == expected
        }

        XCTAssertTrue(contains, "Expected arguments to contain \(expected), got \(arguments)", file: file, line: line)
    }
}
