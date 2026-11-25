import XCTest

@MainActor
final class SimilarSongsTests: XCTestCase {
    func testArtistChoiceOpensVerifiedArtistAndRetriesHandoff() {
        let app = launch("similarArtists")
        tap(app.buttons["Midnight City, M83"])
        tap(app.buttons["Similar Artists"])

        let first = result("CHVRCHES", in: app)
        let second = result("Purity Ring", in: app)
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        let results = app.scrollViews["discoveryResults"]
        XCTAssertTrue(results.staticTexts["M83"].exists)
        XCTAssertFalse(results.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.buttons["Similar Artists"].isSelected)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        XCTAssertEqual(app.buttons.matching(identifier: first.label).count, 1)
        XCTAssertFalse(result("Phoenix", in: app).exists)
        XCTAssertFalse(result("Unavailable Artist", in: app).exists)
        XCTAssertFalse(result("Missing URL", in: app).exists)
        XCTAssertFalse(result("Wrong URL", in: app).exists)

        tap(first)
        let alert = app.alerts["Couldn’t open Apple Music"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        tap(alert.buttons["Retry"])
        let destination = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(destination.wait(for: .runningForeground, timeout: 10))
        app.activate()
        XCTAssertTrue(first.exists)
    }

    func testSwitchingModesKeepsTheSeedAndIgnoresSupersededArtistResults() {
        let app = launch("modeSwitch")
        startDiscovery(in: app)
        let song = result("A Real Hero, College", in: app)
        let results = app.scrollViews["discoveryResults"]
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Similar Songs"].isSelected)

        tap(app.buttons["Similar Artists"])
        XCTAssertTrue(result("CHVRCHES", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Loading similar artists…"].exists)
        XCTAssertTrue(results.staticTexts["M83"].exists)
        XCTAssertFalse(results.staticTexts["Midnight City"].exists)
        XCTAssertFalse(song.exists)
        XCTAssertTrue(app.buttons["Similar Artists"].isSelected)

        tap(app.buttons["Similar Songs"])
        XCTAssertTrue(song.waitForExistence(timeout: 5))
        XCTAssertTrue(results.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.buttons["Similar Songs"].isSelected)

        let staleResult = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"), object: result("Purity Ring", in: app)
        )
        staleResult.isInverted = true
        wait(for: [staleResult], timeout: 8)
        XCTAssertTrue(song.exists)
        XCTAssertFalse(result("CHVRCHES", in: app).exists)
    }

    func testDismissingChoiceDoesNotStartDiscoveryAndExplicitChoiceOpensVerifiedSong() {
        let app = launch("similarSongs")
        let seed = app.buttons["Midnight City, M83"]
        tap(seed)
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        XCTAssertTrue(app.staticTexts["M83"].exists)
        tap(app.buttons["Cancel"])
        tap(seed)
        tap(app.buttons["Similar Songs"])

        let results = app.scrollViews["discoveryResults"]
        XCTAssertTrue(results.staticTexts["Loading similar songs…"].waitForExistence(timeout: 3))
        XCTAssertTrue(results.buttons["Similar Songs"].isSelected)
        XCTAssertTrue(results.staticTexts["Midnight City"].exists)
        XCTAssertTrue(results.staticTexts["M83"].exists)

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
        XCTAssertTrue(app.buttons["Similar Songs"].isSelected)
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        tap(app.buttons["Choose Another Song"])
        XCTAssertTrue(app.buttons["Digital Love, Daft Punk"].waitForExistence(timeout: 5))
    }

    func testLookupFailureKeepsVerifiedResultsAndRetryRestoresOrder() {
        let app = launch("similarSongsRetry")
        startDiscovery(in: app)

        XCTAssertTrue(app.staticTexts["Couldn’t finish loading similar songs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Similar Songs"].isSelected)
        XCTAssertTrue(app.staticTexts["Midnight City"].exists)
        let first = result("A Real Hero, College", in: app)
        let second = result("Intro, The xx", in: app)
        XCTAssertTrue(first.exists)
        XCTAssertFalse(second.exists)
        tap(first)
        tap(app.buttons["Retry Lookup"])
        XCTAssertTrue(app.alerts["Couldn’t open Apple Music"].waitForExistence(timeout: 5))
        tap(app.alerts.buttons["Cancel"])

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
        XCTAssertTrue(app.buttons["Similar Artists"].isHittable)
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
        tap(app.buttons["Similar Songs"])

        let mode = app.buttons["Similar Songs"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertTrue(mode.isSelected)
        XCTAssertTrue(app.buttons["Similar Artists"].isHittable)
        let first = result("A Real Hero, College", in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        if !first.isHittable { app.swipeUp() }
        XCTAssertTrue(first.isHittable)
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])

        app.swipeDown()
        tap(app.buttons["Similar Artists"])
        let artist = result("CHVRCHES", in: app)
        XCTAssertTrue(artist.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Similar Artists"].isSelected)
        if !artist.isHittable { app.swipeUp() }
        XCTAssertTrue(artist.isHittable)
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
