import XCTest

@MainActor
final class SimilarSongsTests: XCTestCase {
    func testDismissingChoiceDoesNotStartDiscoveryAndExplicitChoiceOpensVerifiedSong() {
        let app = launch("similarSongs")
        let seed = app.buttons["Midnight City, M83"]
        tap(seed)
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.staticTexts["M83"].exists)
        tap(app.buttons["Cancel"])
        tap(seed)
        tap(app.buttons["Similar Songs"])

        XCTAssertTrue(app.staticTexts["Loading similar songs…"].exists)
        XCTAssertTrue(app.staticTexts["Similar Songs"].exists)
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.staticTexts["M83"].exists)

        let first = result("A Real Hero, College", in: app)
        let second = result("Intro, The xx", in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts.matching(identifier: "Opens in Apple Music").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: first.label).count, 1)
        XCTAssertTrue(second.exists)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        XCTAssertFalse(result("A Real Hero, Cover Artist", in: app).exists)
        XCTAssertFalse(result("A Real Hero (Live), College", in: app).exists)
        XCTAssertFalse(result("Missing URL, Sample Artist", in: app).exists)
        XCTAssertFalse(result("Unavailable, Sample Artist", in: app).exists)
        XCTAssertFalse(result("Ambiguous, Sample Artist", in: app).exists)

        tap(first)
        let alert = app.alerts["Couldn’t open Apple Music"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        tap(alert.buttons["Retry"])
        let destination = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(destination.wait(for: .runningForeground, timeout: 10))
        app.activate()
        XCTAssertTrue(first.exists)
    }

    func testZeroMatchesOffersAnotherRecentSong() {
        let app = launch("similarSongsEmpty")
        startDiscovery(in: app)

        XCTAssertTrue(app.staticTexts["No matches"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Similar Songs"].exists)
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        tap(app.buttons["Choose Another Song"])
        XCTAssertTrue(app.buttons["Digital Love, Daft Punk"].waitForExistence(timeout: 5))
    }

    func testLookupFailureKeepsVerifiedResultsAndRetryRestoresOrder() {
        let app = launch("similarSongsRetry")
        startDiscovery(in: app)

        XCTAssertTrue(app.staticTexts["Couldn’t finish loading similar songs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Similar Songs"].exists)
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        let first = result("A Real Hero, College", in: app)
        let second = result("Intro, The xx", in: app)
        XCTAssertTrue(first.exists)
        XCTAssertFalse(second.exists)
        tap(first)
        XCTAssertTrue(app.alerts["Couldn’t open Apple Music"].waitForExistence(timeout: 5))
        tap(app.alerts.buttons["Cancel"])
        tap(app.buttons["Retry Lookup"])

        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertTrue(first.exists)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        XCTAssertFalse(app.buttons["Retry Lookup"].exists)
    }

    func testChoiceAndResultsSupportLargestDynamicTypeSize() throws {
        let app = launch("similarSongs", arguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ])

        tap(app.buttons["Midnight City, M83"])
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.staticTexts["M83"].exists)
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
        tap(app.buttons["Similar Songs"])

        let mode = app.staticTexts["Similar Songs"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertTrue(mode.isSelected)
        let first = result("A Real Hero, College", in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        if !first.isHittable { app.swipeUp() }
        XCTAssertTrue(first.isHittable)
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
    }

    private func result(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["Open \(label) in Apple Music"]
    }

    private func startDiscovery(in app: XCUIApplication) {
        tap(app.buttons["Midnight City, M83"])
        tap(app.buttons["Similar Songs"])
    }

    private func tap(_ button: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Expected \(button)", file: file, line: line)
        button.tap()
    }

    private func launch(_ scenario: String, arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-recentlyPlayedFixture", scenario] + arguments
        app.launch()
        return app
    }
}
