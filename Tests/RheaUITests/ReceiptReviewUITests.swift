import XCTest

/// Scenarios:
///  - Select receipt → edit a line-item price → value persists after reselect.
///  - Confirm receipt → form goes read-only.
///
/// Both drive the same imported+extracted receipt, since editing without confirming is a
/// local draft (`ReceiptEditForm` only writes back to the store via Confirm) — so "persists
/// after reselect" here means: edit, Confirm (which does persist), navigate away and back,
/// and check the value survived the round trip through the on-disk vault and the field is
/// now locked. Noted as a decision on the ticket.
final class ReceiptReviewUITests: XCTestCase {

    @MainActor
    private func launchWithExtractedReceipt() throws -> (app: XCUIApplication, server: StubExtractionServer) {
        let pdfURL = try XCTUnwrap(UITestApp.fixtureURL("testmart_by_weight", ext: "pdf"))
        let responseText = try UITestApp.fixtureText("testmart_by_weight", ext: "txt")
        let server = try StubExtractionServer(modelResponseContent: responseText)
        try server.start()

        let (app, _) = UITestApp.launch(extractionServer: server, importFixturePDF: pdfURL)

        // Import selects the "Queued" filter tab, but the stub server can finish extraction
        // before this test gets to look — switch to "All" so the row stays visible regardless
        // of which status it's landed in by the time we check.
        app.radioButtons["All"].click()

        let row = app.element(identifierPrefix: "receipt-row-")
        XCTAssertTrue(row.waitForExistence(timeout: 15), "receipt should finish importing")
        row.click()

        let priceField = app.element(id: "line-item-price-0")
        XCTAssertTrue(priceField.waitForExistence(timeout: 15), "extraction should complete and show line items")
        return (app, server)
    }

    @MainActor
    func testEditingLineItemPricePersistsAfterConfirmAndReselect() throws {
        let (app, server) = try launchWithExtractedReceipt()
        defer { server.stop(); app.terminate() }

        let priceField = app.element(id: "line-item-price-0")
        XCTAssertEqual(priceField.value as? String, "1.93")

        priceField.click()
        priceField.typeKey("a", modifierFlags: .command)
        priceField.typeText("5.55")

        let confirmButton = app.element(id: "confirm-button")
        XCTAssertTrue(confirmButton.exists)
        confirmButton.click()

        // Deselect (via Settings) and reselect (via Receipts) to force the detail pane to
        // rebuild from scratch, proving the edit round-tripped through the store, not just
        // through in-memory SwiftUI state.
        app.element(id: "sidebar-settings").click()
        app.element(id: "sidebar-receipts").click()
        app.element(identifierPrefix: "receipt-row-").click()

        let reselectedField = app.element(id: "line-item-price-0")
        XCTAssertTrue(reselectedField.waitForExistence(timeout: 10))
        XCTAssertEqual(reselectedField.value as? String, "5.55")
        XCTAssertFalse(reselectedField.isEnabled, "field should be read-only once confirmed")
    }

    @MainActor
    func testConfirmingReceiptMakesFormReadOnly() throws {
        let (app, server) = try launchWithExtractedReceipt()
        defer { server.stop(); app.terminate() }

        let priceField = app.element(id: "line-item-price-0")
        XCTAssertTrue(priceField.isEnabled, "field should be editable before confirming")

        app.element(id: "confirm-button").click()

        XCTAssertTrue(app.staticTexts["Confirmed & Saved"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.element(id: "line-item-price-0").isEnabled)
        XCTAssertFalse(app.element(id: "confirm-button").exists, "Confirm button is replaced by the confirmed banner")
    }
}
