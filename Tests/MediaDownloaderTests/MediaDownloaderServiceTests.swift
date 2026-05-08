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
