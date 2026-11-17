import XCTest
import XCUIAutomation

final class DDMUpdateCompanionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPreferencesOpenWithoutPendingUpdateAndValidateInput() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--preferences"]
        app.launch()
        defer { app.terminate() }
        let window = app.windows["DDM Update Companion Preferences"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let support = window.textFields["supportURL"]
        XCTAssertTrue(support.exists)
        if !support.isEnabled {
            XCTAssertTrue(window.staticTexts["Managed by your organization"].firstMatch.exists)
            XCTAssertTrue(window.buttons["Refresh Now"].exists)
            return
        }
        support.click()
        support.typeKey("a", modifierFlags: .command)
        support.typeText("http://invalid.example.com")
        window.buttons["savePreferences"].click()
        XCTAssertTrue(window.staticTexts["The support address must be an HTTPS URL with a host."].waitForExistence(timeout: 5))
        window.buttons["Reload"].click()
        XCTAssertTrue(window.staticTexts["Preferences reloaded."].exists)
        XCTAssertTrue(window.buttons["Refresh Now"].exists)
    }
}
