import XCTest

@MainActor
final class RecentlyPlayedTests: XCTestCase {
    func testPermissionExplainsWhyAndLoadsSongsAfterTapping() {
        let app = launch("permission")

        XCTAssertTrue(app.staticTexts["Allow Apple Music access to see the songs you’ve played recently."].exists)
        XCTAssertFalse(app.staticTexts["Midnight City, M83"].exists)
        tap("Allow Apple Music Access", in: app)

        let first = app.staticTexts["Midnight City, M83"]
        let second = app.staticTexts["Digital Love, Daft Punk"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.exists)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
    }

    func testDeniedAccessLoadsSongsAfterReturningFromSettings() {
        let app = launch("denied")

        XCTAssertTrue(app.staticTexts["Apple Music access is off"].exists)
        tap("Open Settings", in: app)

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
        app.activate()

        XCTAssertTrue(app.staticTexts["Midnight City, M83"].waitForExistence(timeout: 5))
    }

    func testRestrictedAccessExplainsTheRestriction() {
        let app = launch("restricted")

        XCTAssertTrue(app.staticTexts["Apple Music access is restricted"].exists)
        XCTAssertFalse(app.buttons["Open Settings"].exists)
    }

    func testEmptyResultsExplainHowToGetStarted() {
        let app = launch("empty")

        XCTAssertTrue(app.staticTexts["No recent songs"].exists)
        XCTAssertTrue(app.staticTexts["Play a few songs in Apple Music, then come back and refresh."].exists)
        tap("Refresh", in: app)

        XCTAssertTrue(app.staticTexts["Midnight City, M83"].waitForExistence(timeout: 5))
    }

    func testRefreshReplacesThePreviousSongs() {
        let app = launch("refresh")

        XCTAssertTrue(app.staticTexts["Midnight City, M83"].waitForExistence(timeout: 5))
        tap("Refresh", in: app)

        XCTAssertTrue(app.staticTexts["Archangel, Burial"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Midnight City, M83"].exists)
    }

    func testRetryRecoversFromARequestFailure() {
        let app = launch("retry")

        XCTAssertTrue(app.staticTexts["Couldn’t load recent songs"].exists)
        tap("Try Again", in: app)

        XCTAssertTrue(app.staticTexts["Midnight City, M83"].waitForExistence(timeout: 5))
    }

    func testRecentlyPlayedAtLargestDynamicTypeSize() throws {
        let app = launch("accessibility", arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])

        let heading = app.staticTexts["Recently Played"]
        XCTAssertTrue(heading.exists)
        XCTAssertTrue(app.buttons["Refresh"].exists)
        let row = app.staticTexts["A song title long enough to wrap across multiple lines, An artist credit that also wraps"]
        XCTAssertTrue(row.exists)
        XCTAssertGreaterThan(row.frame.height, 150)
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
    }

    private func tap(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 5) {
            button.tap()
        } else {
            XCTFail("Expected a \(label) button")
        }
    }

    private func launch(_ scenario: String, arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-recentlyPlayedFixture", scenario] + arguments
        app.launch()
        return app
    }
}
