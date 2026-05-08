@testable import MediaDownloader
import XCTest

final class DependencyCheckerTests: XCTestCase {
    func testCodexNodePathIsSearchableWhenPresent() {
        let nodePath = DependencyChecker.executablePath(named: "node")

        XCTAssertNotNil(nodePath)
    }
}
