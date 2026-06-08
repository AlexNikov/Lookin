//
//  InspectorSmokeTests.swift
//  LookinClientUITests
//

import XCTest

final class InspectorSmokeTests: LookinUITestCase {
    func testInspectorOpens() throws {
        launchLookinForUITest()
        _ = waitForInspectorReady()
        XCTAssertTrue(hierarchyOutline.waitForExistence(timeout: 30))
    }

    func testHierarchyOutlineHasRows() throws {
        launchLookinForUITest()
        _ = waitForInspectorReady()
        waitForHierarchyRows(minimum: 5)
    }
}
