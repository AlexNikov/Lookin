//
//  InspectorHiddenPreviewTests.swift
//  LookinClientUITests
//

import XCTest

final class InspectorHiddenPreviewTests: LookinUITestCase {
    private let hiddenBadgeTitle = "HiddenBadgeView"

    func testPreviewStructureHidesHiddenLayerByDefault() throws {
        launchLookinForUITest()
        let lines = waitForPreviewStructure()
        recordPreviewFixtureIfRequested(lines, name: "preview-structure-hidden-off.norm")

        LookinPreviewStructureCompare.assertHiddenPreviewTitles([], in: lines)
        LookinPreviewStructureCompare.assertTreeMatchesFixture(
            actual: lines,
            fixtureName: "preview-structure-hidden-off.norm"
        )
    }

    func testShowHiddenRevealsLayerInPreviewStructure() throws {
        launchLookinForUITest(showHiddenItems: true)
        let lines = waitForPreviewStructure()
        recordPreviewFixtureIfRequested(lines, name: "preview-structure-hidden-on.norm")

        LookinPreviewStructureCompare.assertHiddenPreviewTitles([hiddenBadgeTitle], in: lines)
        LookinPreviewStructureCompare.assertTreeMatchesFixture(
            actual: lines,
            fixtureName: "preview-structure-hidden-on.norm"
        )
    }

    private func recordPreviewFixtureIfRequested(_ lines: [String], name: String) {
        guard LookinUITestConfig.load().recordPreviewFixtures else { return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
        let body = lines.joined(separator: "\n")
        try? body.write(to: url, atomically: true, encoding: .utf8)
    }
}
