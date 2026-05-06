@testable import MediaDownloader
import XCTest

final class HistoryKeyboardViewportTests: XCTestCase {
    func testFirstFourSelectionsDoNotScroll() {
        var viewport = HistoryKeyboardViewport(visibleRowLimit: 4)

        XCTAssertNil(viewport.scrollTarget(for: 0, itemCount: 9))
        XCTAssertEqual(viewport.visibleStartIndex, 0)

        XCTAssertNil(viewport.scrollTarget(for: 1, itemCount: 9))
        XCTAssertNil(viewport.scrollTarget(for: 2, itemCount: 9))
        XCTAssertNil(viewport.scrollTarget(for: 3, itemCount: 9))
        XCTAssertEqual(viewport.visibleStartIndex, 0)
    }

    func testMovingDownScrollsOnlyWhenSelectionLeavesVisibleWindow() {
        var viewport = HistoryKeyboardViewport(visibleRowLimit: 4)

        _ = viewport.scrollTarget(for: 0, itemCount: 9)
        _ = viewport.scrollTarget(for: 1, itemCount: 9)
        _ = viewport.scrollTarget(for: 2, itemCount: 9)
        _ = viewport.scrollTarget(for: 3, itemCount: 9)

        XCTAssertEqual(viewport.scrollTarget(for: 4, itemCount: 9), HistoryKeyboardScrollTarget(index: 4, edge: .bottom))
        XCTAssertEqual(viewport.visibleStartIndex, 1)
        XCTAssertEqual(viewport.scrollTarget(for: 5, itemCount: 9), HistoryKeyboardScrollTarget(index: 5, edge: .bottom))
        XCTAssertEqual(viewport.visibleStartIndex, 2)
        XCTAssertEqual(viewport.scrollTarget(for: 6, itemCount: 9), HistoryKeyboardScrollTarget(index: 6, edge: .bottom))
        XCTAssertEqual(viewport.visibleStartIndex, 3)
    }

    func testMovingUpAfterScrollingDownScrollsAsSoonAsSelectionLeavesWindow() {
        var viewport = HistoryKeyboardViewport(visibleRowLimit: 4)

        for index in 0...6 {
            _ = viewport.scrollTarget(for: index, itemCount: 9)
        }

        XCTAssertEqual(viewport.visibleStartIndex, 3)
        XCTAssertNil(viewport.scrollTarget(for: 5, itemCount: 9))
        XCTAssertNil(viewport.scrollTarget(for: 4, itemCount: 9))
        XCTAssertNil(viewport.scrollTarget(for: 3, itemCount: 9))

        XCTAssertEqual(viewport.scrollTarget(for: 2, itemCount: 9), HistoryKeyboardScrollTarget(index: 2, edge: .top))
        XCTAssertEqual(viewport.visibleStartIndex, 2)
        XCTAssertEqual(viewport.scrollTarget(for: 1, itemCount: 9), HistoryKeyboardScrollTarget(index: 1, edge: .top))
        XCTAssertEqual(viewport.visibleStartIndex, 1)
        XCTAssertEqual(viewport.scrollTarget(for: 0, itemCount: 9), HistoryKeyboardScrollTarget(index: 0, edge: .top))
        XCTAssertEqual(viewport.visibleStartIndex, 0)
    }
}
