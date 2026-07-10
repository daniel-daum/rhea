import Testing
import Foundation
@testable import Rhea

struct ReceiptKeysTests {
    @Test func slugComponentCollapsesNonAlphanumerics() {
        #expect(slugComponent("TRADER JOE'S") == "trader-joe-s")
    }

    @Test func naturalKeyFallsBackToPublicIDWhenChainMissing() {
        let receipt = Receipt(
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic.pdf"),
            status: .done,
            extracted: ExtractedReceipt(
                merchant: "Synthetic Grocery",
                date: "2026-01-01",
                total: Decimal(9.99),
                lineItems: []
            )
        )
        #expect(receipt.naturalKey == receipt.publicID)
    }

    @Test func naturalKeyUsesChainStoreDateReceiptWhenAvailable() {
        let receipt = Receipt(
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic.pdf"),
            status: .done,
            extracted: ExtractedReceipt(
                merchant: "Synthetic Grocery",
                chain: "Synthetic Grocery",
                storeNumber: "123",
                date: "2026-01-01T00:00:00Z",
                receiptNumber: "R-42",
                total: Decimal(9.99),
                lineItems: []
            )
        )
        #expect(receipt.naturalKey == "synthetic-grocery_123_2026-01-01_r-42")
    }

    @Test func lineItemStableKeyPrefersBarcode() {
        let item = LineItem(name: "Synthetic Item", barcode: "012345")
        #expect(item.stableKey(receiptKey: "unused", index: 0) == "barcode_012345")
    }

    @Test func lineItemStableKeyFallsBackToReceiptKeyAndIndex() {
        let item = LineItem(name: "Synthetic Item")
        #expect(item.stableKey(receiptKey: "some_receipt", index: 2) == "some_receipt_item03")
    }
}
