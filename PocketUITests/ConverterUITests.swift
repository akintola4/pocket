//
//  ConverterUITests.swift
//  PocketUITests
//
//  The converter with real touches. `-PocketNoSplash` skips the opening
//  animation, and `-PocketDemoRates` pins the rates to the bundled snapshot
//  (1 USD = 1,346.60127178 NGN) so the numbers are the same on every run,
//  online or not. XCTest because Swift Testing can't drive the UI.
//

import XCTest

@MainActor
final class ConverterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-PocketNoSplash", "-PocketDemoRates",
            // Formatting follows the region, so pin it.
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
    }

    private var amountField: XCUIElement { app.textFields["amount-field"] }
    private var result: XCUIElement { app.descendants(matching: .any)["converted-amount"] }

    /// Waits for the result's label to contain `text`, without a fixed sleep.
    private func waitForResult(containing text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: result)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// No splash: the converter is the first thing on screen, on USD → NGN
    /// with the starting $100.
    func testOpensOnTheConverter() {
        XCTAssertTrue(app.staticTexts["Currency"].waitForExistence(timeout: 5))
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        XCTAssertEqual(amountField.value as? String, "100")
        XCTAssertTrue(app.buttons["From US Dollar"].exists)
        XCTAssertTrue(app.buttons["To Nigerian Naira"].exists)
        XCTAssertTrue(waitForResult(containing: "₦134,660.13"))
    }

    /// Typing a new amount updates the converted value as you go.
    func testTypingAnAmountUpdatesTheResult() {
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        // Works with or without the Simulator's hardware keyboard connected.
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: amountField)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 5), .completed)
        let current = amountField.value as? String ?? ""
        amountField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 1))
        amountField.typeText("250")

        XCTAssertEqual(amountField.value as? String, "250")
        // 250 × 1,346.60127178 = 336,650.317945
        XCTAssertTrue(waitForResult(containing: "₦336,650.32"), "Result was \(result.label)")
    }
}
