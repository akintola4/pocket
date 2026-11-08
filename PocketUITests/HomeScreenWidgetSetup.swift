//
//  HomeScreenWidgetSetup.swift
//  PocketUITests
//
//  Not a check: puts Pocket's medium and small widgets on the first Home
//  Screen page through SpringBoard's own Add Widget sheet, so
//  scripts/screenshots.sh can take a real widgets-home.png. Skipped unless
//  POCKET_ADD_WIDGETS is set (the script sets TEST_RUNNER_POCKET_ADD_WIDGETS).
//

import XCTest

@MainActor
final class HomeScreenWidgetSetup: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["POCKET_ADD_WIDGETS"] != nil,
                          "Only for scripts/screenshots.sh")
        continueAfterFailure = false
    }

    func testAddPocketWidgetsToTheHomeScreen() {
        // Run on a freshly erased Simulator, where this lands on the first page.
        XCUIDevice.shared.press(.home)

        // The small one last, so it ends up on top.
        addWidget(page: 1)
        addWidget(page: 0)

        springboard.buttons["Done"].tap()
    }

    /// `page` is the size in the gallery: 0 small, 1 medium.
    private func addWidget(page: Int) {
        let edit = springboard.buttons["Edit"]
        // After the first widget the Home Screen is still in edit mode.
        if !edit.exists {
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).press(forDuration: 1.5)
            XCTAssertTrue(edit.waitForExistence(timeout: 5))
        }
        edit.tap()
        let add = springboard.buttons["Add Widget"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let search = springboard.searchFields["Search Widgets"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Pocket")
        let cell = springboard.cells["Pocket"]
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()

        let preview = springboard.buttons["Pocket, Exchange rate"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        for _ in 0..<page { preview.swipeLeft() }
        let confirm = springboard.buttons.matching(NSPredicate(format: "label ENDSWITH 'Add Widget'")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }
}
