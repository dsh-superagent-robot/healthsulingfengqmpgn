import XCTest

final class HealthSenseUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-DSHDemoData", "-DSHPremium", "-DSHTab", "0"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Log Health Data"].waitForExistence(timeout: 10))

        app.buttons["Dashboard"].tap()
        XCTAssertTrue(app.staticTexts["Your averages"].waitForExistence(timeout: 6))

        app.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Learn your heart"].waitForExistence(timeout: 6))

        app.buttons["Me"].tap()
        XCTAssertTrue(app.staticTexts["My Statistics"].waitForExistence(timeout: 6))
    }

    func testMeasurementFlow() {
        let app = XCUIApplication()
        app.launchArguments = ["-DSHDemoData", "-DSHPremium", "-DSHSkipCameraTutorial", "-DSHTab", "0"]
        app.launch()

        let measure = app.buttons["measureTabButton"]
        XCTAssertTrue(measure.waitForExistence(timeout: 10))
        measure.tap()

        XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout: 6))
        app.buttons["mode_fast"].tap()
        app.buttons["startMeasurementButton"].tap()

        XCTAssertTrue(app.staticTexts["Measurement"].waitForExistence(timeout: 35))
        XCTAssertTrue(app.buttons["resultContinueButton"].exists)
    }

    func testSettingsAndPaywallForFreeMember() {
        let app = XCUIApplication()
        app.launchArguments = ["-DSHDemoData", "-DSHFree", "-DSHTab", "0"]
        app.launch()

        XCTAssertTrue(app.buttons["premiumBanner"].waitForExistence(timeout: 10))
        app.buttons["premiumBanner"].tap()
        XCTAssertTrue(app.buttons["purchaseButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Weekly Pro"].exists)
        XCTAssertTrue(app.staticTexts["Yearly Pro"].exists)
    }
}
