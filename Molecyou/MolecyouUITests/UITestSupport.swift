import XCTest

/// Shared base class + helpers for Molecyou UI tests.
///
/// Launch arguments understood by the app (see `AppEnvironment.live` / `RootView`):
/// - `-hasCompletedOnboarding YES|NO`, `-demonstrationMode YES|NO`
/// - `UITestPreviewAlphaFold` (bundled sample structure, no network)
/// - `UITestLinkedHealthData`, `UITestNoHealthData`
class MolecyouUITestCase: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    var baseArguments: [String] {
        ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    @MainActor
    func launchCompletedApp(extraArguments: [String] = ["-demonstrationMode", "YES", "UITestPreviewAlphaFold"]) -> XCUIApplication {
        let app = XCUIApplication()
        // "UITesting" makes the app use an in-memory SwiftData store, isolating each test.
        app.launchArguments = baseArguments + ["UITesting", "-hasCompletedOnboarding", "YES"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    func search(_ app: XCUIApplication, text: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 6), "Search field should appear")
        field.tap()
        field.typeText(text)
    }

    /// Opens the Explore tab, searches for `term`, and taps the result with the given `name`.
    @MainActor
    func openProtein(_ app: XCUIApplication, term: String, name: String) {
        app.tabBars.buttons["Explore"].tap()
        search(app, text: term)
        let cell = app.staticTexts[name]
        XCTAssertTrue(cell.waitForExistence(timeout: 6), "Expected result \(name)")
        cell.tap()
    }

    /// Scrolls the controls scroll view until `element` is hittable. The drag is anchored to
    /// the scroll view's lower region (below the SceneKit viewer, whose camera control would
    /// otherwise capture the gesture) so it scrolls rather than rotating the model.
    @MainActor
    @discardableResult
    func scrollControls(_ app: XCUIApplication, until element: XCUIElement, maxDrags: Int = 8) -> Bool {
        let scroll = app.scrollViews.firstMatch
        var drags = 0
        while !element.isHittable && drags < maxDrags {
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            start.press(forDuration: 0.08, thenDragTo: end)
            drags += 1
        }
        return element.isHittable
    }

    /// Swipes up on the whole screen until `element` is on screen and tappable. Suitable for
    /// plain scroll views / Lists (no SceneKit viewer to intercept the gesture).
    @MainActor
    @discardableResult
    func swipeUpUntilHittable(_ app: XCUIApplication, _ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        return element.isHittable
    }
}
