import XCTest

final class MolecyouUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAndCompletedLaunchStates() throws {
        let onboardingApp = XCUIApplication()
        onboardingApp.launchArguments = baseArguments + ["-hasCompletedOnboarding", "NO"]
        onboardingApp.launch()
        XCTAssertTrue(onboardingApp.buttons["Onboarding Welcome Continue"].waitForExistence(timeout: 4))
        onboardingApp.terminate()

        let completedApp = XCUIApplication()
        completedApp.launchArguments = baseArguments + ["-hasCompletedOnboarding", "YES", "-demonstrationMode", "YES"]
        completedApp.launch()
        XCTAssertTrue(completedApp.tabBars.buttons["Today"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testDemoUserCanBrowseEducationWithoutLinkingHealthKit() throws {
        let app = launchCompletedApp(extraArguments: ["-demonstrationMode", "YES", "UITestPreviewAlphaFold"])
        XCTAssertTrue(app.descendants(matching: .any)["Today Demo Data"].waitForExistence(timeout: 6))

        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.staticTexts["Body Atlas"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Oxygen Transport"].exists)

        search(app, text: "CLOCK")
        XCTAssertTrue(app.staticTexts["CLOCK"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testNoHealthDataUserStillGetsEducationalExperience() throws {
        let app = launchCompletedApp(extraArguments: ["-demonstrationMode", "NO", "UITestNoHealthData"])
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["Today No Health Data"].waitForExistence(timeout: 6))

        app.tabBars.buttons["Explore"].tap()
        search(app, text: "Hemoglobin")
        XCTAssertTrue(app.staticTexts["Hemoglobin subunit beta"].waitForExistence(timeout: 4))

        app.staticTexts["Hemoglobin subunit beta"].tap()
        XCTAssertTrue(app.buttons["Open 3D Viewer"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testLinkedHealthUserGetsFullHealthContextRecommendations() throws {
        let app = launchCompletedApp(extraArguments: ["-demonstrationMode", "NO", "UITestLinkedHealthData", "UITestPreviewAlphaFold"])
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.descendants(matching: .any)["Today Linked Health Data"].waitForExistence(timeout: 6))
        let oxygenLink = app.buttons["SystemFocus oxygen-transport"]
        XCTAssertTrue(oxygenLink.waitForExistence(timeout: 4))
        oxygenLink.tap()
        XCTAssertTrue(app.staticTexts["Key Proteins"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testProteinDetailSaveAndViewerEntryPoint() throws {
        let app = launchCompletedApp(extraArguments: ["-demonstrationMode", "YES", "UITestPreviewAlphaFold"])
        app.tabBars.buttons["Explore"].tap()
        search(app, text: "P68871")
        XCTAssertTrue(app.staticTexts["Hemoglobin subunit beta"].waitForExistence(timeout: 4))
        app.staticTexts["Hemoglobin subunit beta"].tap()

        XCTAssertTrue(app.buttons["Save Protein"].waitForExistence(timeout: 4))
        app.buttons["Save Protein"].tap()
        XCTAssertTrue(app.buttons["Open 3D Viewer"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["AlphaFold DB"].exists)
    }

    private var baseArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    @MainActor
    private func launchCompletedApp(extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["-hasCompletedOnboarding", "YES"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func search(_ app: XCUIApplication, text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 4))
        field.tap()
        field.typeText(text)
    }
}
