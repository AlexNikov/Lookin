//
//  LookinUITestCase.swift
//  LookinClientUITests
//

import XCTest

class LookinUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: LookinUITestCase.lookinBundleID)
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func launchLookinForUITest(showHiddenItems: Bool = false) {
        app.launchArguments = ["-LookinUITest"]
        app.launchEnvironment["LOOKIN_UI_TEST"] = "1"
        if showHiddenItems {
            app.launchEnvironment["LOOKIN_UI_TEST_SHOW_HIDDEN"] = "1"
        }
        app.launch()
    }

    @discardableResult
    func waitForInspectorReady(timeout: TimeInterval = 90) -> XCUIElement {
        let inspector = app.windows.matching(identifier: LookinAccessibilityID.inspectorWindow).firstMatch
        XCTAssertTrue(inspector.waitForExistence(timeout: timeout), "Inspector window did not appear")
        let ready = inspector.waitForValue("ready", timeout: timeout)
        XCTAssertTrue(ready, "Inspector window never reached ready state")
        return inspector
    }

    @discardableResult
    func waitForPreviewStructure(timeout: TimeInterval = 90) -> [String] {
        _ = waitForInspectorReady(timeout: timeout)
        let preview = app.descendants(matching: .any)[LookinAccessibilityID.previewStructure].firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: timeout), "Preview structure element missing")

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let raw = preview.value as? String, !raw.isEmpty {
                let lines = raw
                    .split(separator: "\u{001E}", omittingEmptySubsequences: false)
                    .map { String($0) }
                    .filter { !$0.isEmpty }
                if lines.contains(where: { $0.hasPrefix("oid=") }) {
                    return lines
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Preview structure never published oid= lines")
        return []
    }

    var hierarchyOutline: XCUIElement {
        let table = app.tables[LookinAccessibilityID.hierarchyOutline]
        if table.exists { return table }
        return app.descendants(matching: .any)[LookinAccessibilityID.hierarchyOutline]
    }

    func waitForHierarchyRows(minimum: Int = 5, timeout: TimeInterval = 90) {
        XCTAssertTrue(hierarchyOutline.waitForExistence(timeout: timeout), "Hierarchy outline missing")
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hierarchyRowLabels().count >= minimum {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Expected at least \(minimum) hierarchy rows, found \(hierarchyRowLabels().count)")
    }

    func hierarchyRowLabels(limit: Int = 20) -> [String] {
        let ignored = Set(["Filter", "Hierarchy"])
        var labels = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { label in
            !label.isEmpty && !ignored.contains(label)
        }
        if labels.isEmpty {
            labels = app.cells.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
        }
        var seen = Set<String>()
        var ordered: [String] = []
        for label in labels where seen.insert(label).inserted {
            ordered.append(label)
            if ordered.count >= limit { break }
        }
        return ordered
    }

    static let lookinBundleID = "hughkli.Lookin"
}

enum LookinAccessibilityID {
    static let inspectorWindow = "lookin.inspector.window"
    static let hierarchyOutline = "lookin.hierarchy.outline"
    static let previewStructure = "lookin.uitest.preview.structure"
}

private extension XCUIElement {
    func waitForValue(_ value: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if self.value as? String == value {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return self.value as? String == value
    }
}
