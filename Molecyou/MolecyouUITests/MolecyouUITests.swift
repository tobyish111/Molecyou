import XCTest

final class MolecyouUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAndCompletedLaunchStates() throws {
        let onboardingApp = XCUIApplication()
        onboardingApp.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-hasCompletedOnboarding", "NO"]
        onboardingApp.launch()
        XCTAssertTrue(onboardingApp.buttons["Onboarding Welcome Continue"].waitForExistence(timeout: 4))
        onboardingApp.terminate()

        let completedApp = XCUIApplication()
        completedApp.launchArguments = ["-hasCompletedOnboarding", "YES", "-demonstrationMode", "YES"]
        completedApp.launch()
        XCTAssertTrue(completedApp.tabBars.buttons["Today"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testDemoNavigationSearchAndLibrary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES", "-demonstrationMode", "YES"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Explore"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Explore"].tap()
        app.searchFields.firstMatch.tap()
        app.typeText("HBB")
        XCTAssertTrue(app.staticTexts["Hemoglobin subunit beta"].waitForExistence(timeout: 4))
    }
}
