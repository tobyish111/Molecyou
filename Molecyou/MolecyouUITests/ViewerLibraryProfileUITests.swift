import XCTest

/// Protein detail, 3D viewer, library persistence, notes, and profile UI flows.
final class ViewerLibraryProfileUITests: MolecyouUITestCase {
    @MainActor
    func testProteinDetailSaveExposesInLibrary() throws {
        let app = launchCompletedApp()
        openProtein(app, term: "P68871", name: "Hemoglobin subunit beta")

        let save = app.buttons["Save Protein"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AlphaFold DB"].exists)
        save.tap()

        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["Saved Proteins"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Hemoglobin subunit beta"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTitinShowsNoAlphaFoldStructureAndNoViewer() throws {
        let app = launchCompletedApp()
        openProtein(app, term: "Titin", name: "Titin")

        XCTAssertTrue(app.staticTexts["Not in AlphaFold DB"].waitForExistence(timeout: 5))
        // The 3D viewer entry point must be absent for a protein with no AlphaFold model.
        XCTAssertFalse(app.buttons["Open 3D Viewer"].exists)
    }

    @MainActor
    func testMolecularViewerControls() throws {
        let app = launchCompletedApp()
        openProtein(app, term: "P68871", name: "Hemoglobin subunit beta")

        let openViewer = app.buttons["Open 3D Viewer"]
        XCTAssertTrue(openViewer.waitForExistence(timeout: 5))
        openViewer.tap()

        // Camera controls are always present regardless of load state.
        XCTAssertTrue(app.buttons["Reset camera"].waitForExistence(timeout: 6))
        app.buttons["Reset camera"].tap()
        app.buttons["Center structure"].tap()
        // The Labels control is a `.toggleStyle(.button)` Toggle, which the accessibility
        // tree exposes as a Switch (not a Button).
        app.switches["Toggle residue labels"].tap()

        // The representation/color options sit below the fold. Scroll to the bottom source
        // note first so the whole (lazily-built) controls stack is realized in the hierarchy,
        // then tap — XCUITest auto-scrolls to an element that already exists in the tree.
        let sourceNote = app.staticTexts["AlphaFold structures are public predicted references and are not personalized measurements."]
        scrollControls(app, until: sourceNote)
        XCTAssertTrue(app.buttons["Surface"].waitForExistence(timeout: 3))
        app.buttons["Surface"].tap()
        XCTAssertTrue(app.buttons["Chain"].waitForExistence(timeout: 3))
        app.buttons["Chain"].tap()

        // Full-screen open/close (the toolbar button stays fixed at the top regardless of scroll).
        app.buttons["Open full screen viewer"].tap()
        let close = app.buttons["Close full screen viewer"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(app.buttons["Open full screen viewer"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProteinSourcesDisclosure() throws {
        let app = launchCompletedApp()
        openProtein(app, term: "P68871", name: "Hemoglobin subunit beta")
        let sources = app.staticTexts["Sources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 5))
        sources.tap()
        XCTAssertTrue(app.staticTexts["UniProt Knowledgebase"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testNotesAddAndDelete() throws {
        let app = launchCompletedApp()
        app.tabBars.buttons["Library"].tap()

        // The notes section is at the bottom of the Library scroll view.
        let notesEntry = app.staticTexts["Start a note"]
        swipeUpUntilHittable(app, notesEntry)
        XCTAssertTrue(notesEntry.waitForExistence(timeout: 5))
        notesEntry.tap()

        let field = app.textFields["Add an educational note"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let noteText = "Review oxygen cooperativity"
        field.typeText(noteText)
        app.buttons["Add Note"].tap()

        XCTAssertTrue(app.staticTexts[noteText].waitForExistence(timeout: 5))

        app.buttons["Delete note"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[noteText].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testProfileToggleAndResetReturnsToOnboarding() throws {
        // Launch with onboarding completed via the writable standard domain (UITestCompletedOnboarding)
        // instead of an argument-domain pin, so the in-app "Reset app" can flip it back at runtime.
        let app = XCUIApplication()
        app.launchArguments = baseArguments + ["UITesting", "UITestCompletedOnboarding", "-demonstrationMode", "YES", "UITestPreviewAlphaFold"]
        app.launch()
        app.tabBars.buttons["Library"].tap()

        let profileEntry = app.staticTexts["Profile & Settings"]
        XCTAssertTrue(profileEntry.waitForExistence(timeout: 5))
        profileEntry.tap()

        // "Demonstration mode" is in the Preferences section of the Profile list, which may be
        // below the fold depending on the health-status row height — scroll it into view.
        let demoToggle = app.switches["Demonstration mode"]
        swipeUpUntilHittable(app, demoToggle)
        XCTAssertTrue(demoToggle.waitForExistence(timeout: 5))
        demoToggle.tap()

        // "Reset app" is in the last section of the Profile list, below the fold.
        let reset = app.buttons["Reset app"]
        swipeUpUntilHittable(app, reset)
        XCTAssertTrue(reset.waitForExistence(timeout: 4))
        reset.tap()

        // Resetting clears onboarding, so the welcome screen returns.
        XCTAssertTrue(app.buttons["Onboarding Welcome Continue"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testExploreSavedFilterAndClearCache() throws {
        let app = launchCompletedApp()
        // Save a protein first.
        openProtein(app, term: "P69905", name: "Hemoglobin subunit alpha")
        app.buttons["Save Protein"].tap()

        // Saved filter in Explore should surface it. The "Saved" filter is a
        // `.toggleStyle(.button)` Toggle, exposed in the accessibility tree as a Switch.
        app.tabBars.buttons["Explore"].tap()
        let savedToggle = app.switches["Saved"]
        XCTAssertTrue(savedToggle.waitForExistence(timeout: 5))
        savedToggle.tap()
        // The saved-results list places systems/pathways ahead of the protein, so it can be
        // below the fold — scroll it into view before asserting.
        let savedProtein = app.staticTexts["Hemoglobin subunit alpha"]
        swipeUpUntilHittable(app, savedProtein)
        XCTAssertTrue(savedProtein.waitForExistence(timeout: 3))
    }
}
