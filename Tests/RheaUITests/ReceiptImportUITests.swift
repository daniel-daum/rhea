import XCTest

/// Scenario: import a synthetic PDF via the `UITEST_IMPORT_PDF` launch-environment seam
/// (standing in for ⌘O / drag-and-drop, which XCUITest can't drive headlessly through
/// NSOpenPanel) and confirm the receipt row appears in the list.
final class ReceiptImportUITests: XCTestCase {

    @MainActor
    func testImportingPDFShowsReceiptRow() throws {
        let pdfURL = try XCTUnwrap(UITestApp.fixtureURL("testmart_by_weight", ext: "pdf"))
        let responseText = try UITestApp.fixtureText("testmart_by_weight", ext: "txt")
        let server = try StubExtractionServer(modelResponseContent: responseText)
        try server.start()
        defer { server.stop() }

        let (app, _) = UITestApp.launch(extractionServer: server, importFixturePDF: pdfURL)
        defer { app.terminate() }

        // Import selects the "Queued" filter tab, but the stub server can finish extraction
        // before this test gets to look — switch to "All" so the row stays visible regardless
        // of which status it's landed in by the time we check.
        app.radioButtons["All"].click()

        let row = app.element(identifierPrefix: "receipt-row-")
        XCTAssertTrue(row.waitForExistence(timeout: 15), "imported receipt should appear as a row")
        XCTAssertTrue(app.staticTexts["testmart_by_weight.pdf"].exists)
    }
}
