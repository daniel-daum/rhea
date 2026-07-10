import XCTest

final class RheaLaunchUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Scenario: launch, main window appears with sidebar / list / detail.
    @MainActor
    func testMainWindowShowsSidebarListAndDetail() {
        let (app, _) = UITestApp.launch()
        defer { app.terminate() }

        // Sidebar: the Receipts / Settings items render with their identifiers.
        XCTAssertTrue(app.element(id: "sidebar-receipts").waitForExistence(timeout: 10))
        XCTAssertTrue(app.element(id: "sidebar-settings").exists)

        // List: the receipts table and its import affordance render (empty vault, no rows yet).
        XCTAssertTrue(app.element(id: "receipts-table").exists)
        XCTAssertTrue(app.element(id: "import-pdf-button").exists)

        // Detail: with nothing selected, the empty-state placeholder renders.
        XCTAssertTrue(app.staticTexts["No Receipt Selected"].exists)
    }
}
