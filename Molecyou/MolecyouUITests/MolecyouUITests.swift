import XCTest

/// Core navigation, onboarding, and health-context UI flows.
final class MolecyouUITests: MolecyouUITestCase {
    @MainActor
    func testOnboardingAndCompletedLaunchStates() throws {
        let onboardingApp = XCUIApplication()
        onboardingApp.launchArguments = baseArguments + ["-hasCompletedOnboarding", "NO"]
        onboardingApp.launch()
        XCTAssertTrue(onboardingApp.buttons["Onboarding Welcome Continue"].waitForExistence(timeout: 5))
        onboardingApp.terminate()

        let completedApp = XCUIApplication()
        completedApp.launchArguments = baseArguments + ["-hasCompletedOnboarding", "YES", "-demonstrationMode", "YES"]
        completedApp.launch()
        XCTAssertTrue(completedApp.tabBars.buttons["Today"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFullOnboardingFlowReachesToday() throws {
        // Start at onboarding via the writable standard domain (UITestFreshOnboarding), not an
        // argument-domain pin, so tapping through to "Enter Molecyou" can complete it at runtime.
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["UITesting", "UITestFreshOnboarding", "-demonstrationMode", "YES"]
        app.launch()

        XCTAssertTrue(app.buttons["Onboarding Welcome Continue"].waitForExistence(timeout: 5))
        app.buttons["Onboarding Welcome Continue"].tap()
        XCTAssertTrue(app.buttons["Onboarding Privacy Continue"].waitForExistence(timeout: 4))
        app.buttons["Onboarding Privacy Continue"].tap()
        XCTAssertTrue(app.buttons["Onboarding Interests Continue"].waitForExistence(timeout: 4))
        app.buttons["Onboarding Interests Continue"].tap()
        XCTAssertTrue(app.buttons["Onboarding Permission Continue"].waitForExistence(timeout: 4))
        app.buttons["Onboarding Permission Continue"].tap()
        XCTAssertTrue(app.buttons["Enter Molecyou"].waitForExistence(timeout: 4))
        app.buttons["Enter Molecyou"].tap()

        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Today Demo Data"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTabsAreReachable() throws {
        let app = launchCompletedApp()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.staticTexts["Systems"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["Saved Proteins"].waitForExistence(timeout: 4))
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Today Demo Data"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testDemoUserCanBrowseSystemsAndSearch() throws {
        let app = launchCompletedApp()
        XCTAssertTrue(app.descendants(matching: .any)["Today Demo Data"].waitForExistence(timeout: 6))

        app.tabBars.buttons["Explore"].tap()
        // The Explore landing shows a Systems section with system cards (replaces the removed Body Atlas).
        XCTAssertTrue(app.staticTexts["Systems"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Oxygen Transport"].exists)
        XCTAssertTrue(app.staticTexts["Based on Your Activity"].exists)

        search(app, text: "CLOCK")
        XCTAssertTrue(app.staticTexts["CLOCK"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testSearchNoResultsShowsClearFilters() throws {
        let app = launchCompletedApp()
        app.tabBars.buttons["Explore"].tap()
        search(app, text: "ZZZNOTFOUND")
        XCTAssertTrue(app.staticTexts["No results"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Clear filters"].exists)
    }

    @MainActor
    func testSystemDetailShowsKeyProteinsProcessesAndModules() throws {
        let app = launchCompletedApp()
        app.tabBars.buttons["Explore"].tap()
        // Tap the system card via its unique short-description text. The system name alone is
        // ambiguous (it also appears in the "Based on Your Activity" row, which navigates to a
        // module rather than the system detail screen).
        let systemCard = app.staticTexts["How blood carries oxygen to working tissues."]
        XCTAssertTrue(systemCard.waitForExistence(timeout: 5))
        systemCard.tap()

        // Sections stack top-to-bottom (Key Processes, Key Proteins, Related Modules) in a
        // scroll view, so reveal each progressively before asserting.
        let keyProcesses = app.staticTexts["Key Processes"]
        swipeUpUntilHittable(app, keyProcesses)
        XCTAssertTrue(keyProcesses.exists)
        let keyProteins = app.staticTexts["Key Proteins"]
        swipeUpUntilHittable(app, keyProteins)
        XCTAssertTrue(keyProteins.exists)
        let relatedModules = app.staticTexts["Related Modules"]
        swipeUpUntilHittable(app, relatedModules)
        XCTAssertTrue(relatedModules.exists)
    }

    @MainActor
    func testEducationModuleShowsStepsAndCitations() throws {
        let app = launchCompletedApp()
        app.tabBars.buttons["Explore"].tap()
        XCTAssertTrue(app.staticTexts["Oxygen Transport"].waitForExistence(timeout: 5))
        // "Oxygen Transport" appears both as a system card and in the "Based on Your Activity"
        // row, so scope the tap to the first match (the system card).
        app.staticTexts["Oxygen Transport"].firstMatch.tap()

        let module = app.staticTexts["How Hemoglobin Works"]
        XCTAssertTrue(module.waitForExistence(timeout: 5))
        module.tap()

        XCTAssertTrue(app.staticTexts["Steps"].waitForExistence(timeout: 5))
        // Each step is footnoted to a named reference; the Bohr effect backs the "release" steps.
        XCTAssertTrue(app.staticTexts["Physiology, Bohr Effect"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testNoHealthDataUserStillGetsEducationalExperience() throws {
        let app = launchCompletedApp(extraArguments: ["-demonstrationMode", "NO", "UITestNoHealthData"])
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Today No Health Data"].waitForExistence(timeout: 6))

        openProtein(app, term: "Hemoglobin", name: "Hemoglobin subunit beta")
        XCTAssertTrue(app.buttons["Open 3D Viewer"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLinkedHealthUserGetsFullHealthContextRecommendations() throws {
        let app = launchCompletedApp(extraArguments: ["-demonstrationMode", "NO", "UITestLinkedHealthData", "UITestPreviewAlphaFold"])
        XCTAssertTrue(app.descendants(matching: .any)["Today Linked Health Data"].waitForExistence(timeout: 6))
        let oxygenLink = app.buttons["SystemFocus oxygen-transport"]
        XCTAssertTrue(oxygenLink.waitForExistence(timeout: 5))
        oxygenLink.tap()
        XCTAssertTrue(app.staticTexts["Key Proteins"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testHealthContextScreenExplainsRelevance() throws {
        let app = launchCompletedApp(extraArguments: ["-demonstrationMode", "NO", "UITestLinkedHealthData", "UITestPreviewAlphaFold"])
        let oxygenLink = app.buttons["SystemFocus oxygen-transport"]
        XCTAssertTrue(oxygenLink.waitForExistence(timeout: 6))
        oxygenLink.tap()
        let contextRow = app.staticTexts["Relevant HealthKit context"]
        XCTAssertTrue(contextRow.waitForExistence(timeout: 5))
        contextRow.tap()
        XCTAssertTrue(app.staticTexts["Why this appeared"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Matched values"].exists)
    }
}
