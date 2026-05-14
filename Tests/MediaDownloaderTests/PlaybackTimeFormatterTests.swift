@testable import MediaDownloader
import XCTest

final class PlaybackTimeFormatterTests: XCTestCase {
    func testWholeSecondsUseMinuteSecondFormat() {
        XCTAssertEqual(PlaybackTimeFormatter.string(for: 65), "01:05")
    }

    func testFractionalSecondsKeepTenthsWhenNeeded() {
        XCTAssertEqual(PlaybackTimeFormatter.string(for: 65.34), "01:05.3")
    }

    func testHourLongClipsIncludeHours() {
        XCTAssertEqual(PlaybackTimeFormatter.string(for: 3_723.6), "1:02:03.6")
    }

    func testInvalidInputFallsBackToZero() {
        XCTAssertEqual(PlaybackTimeFormatter.string(for: .nan), "00:00")
    }
}
