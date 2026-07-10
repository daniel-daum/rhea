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

    // MARK: - naturalKey: dedup contract for PostgresStore.makeInsertSQL's `receipt_key`
    // (the ON CONFLICT (receipt_key) target, and the FK used to relink line items).

    @Test func naturalKeyOmitsMissingStoreNumberAndReceiptNumberFallsBackToGeneratedReceiptNumberForDedup() {
        let receipt = Receipt(
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic.pdf"),
            status: .done,
            extracted: ExtractedReceipt(
                merchant: "Synthetic Grocery",
                chain: "Synthetic Grocery",
                date: "2026-01-01",
                total: Decimal(9.99),
                lineItems: []
            )
        )
        let expected = "synthetic-grocery_2026-01-01_" + slugComponent(receipt.generatedReceiptNumber)
        #expect(receipt.naturalKey == expected)
        // The generated fallback must actually vary the key per receipt, or two
        // different same-day same-chain receipts would collide on receipt_key.
        #expect(receipt.naturalKey != "synthetic-grocery_2026-01-01_")
    }

    @Test func naturalKeyFallsBackToPublicIDWhenChainAndAllOtherFieldsAreMissing() {
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

    @Test func naturalKeyIsDeterministicAcrossRepeatedCallsSoReceiptKeyOnConflictDedupIsStable() {
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
        let first = receipt.naturalKey
        for _ in 0..<10 {
            #expect(receipt.naturalKey == first)
        }
    }

    @Test func slugComponentCollapsesWhitespaceAndRepeatedPunctuationAndMixedCase() {
        #expect(slugComponent("  Grocery   Outlet #42!!  ") == "grocery-outlet-42")
        #expect(slugComponent("Piedmont---Grocery") == "piedmont-grocery")
        #expect(slugComponent("Store_No.007") == "store-no-007")
        #expect(slugComponent("ALL CAPS CHAIN") == "all-caps-chain")
    }

    // MARK: - stableKey: dedup contract for the receipt_line_items rows makeInsertSQL emits
    // per receipt (keyed off `line_no` via `index`, or a barcode-derived key when available).

    @Test func lineItemStableKeyIsDeterministicAcrossRepeatedCallsForSameLineItemRow() {
        let barcoded = LineItem(name: "Synthetic Item", barcode: "012345")
        let unbarcoded = LineItem(name: "Synthetic Item")
        let firstBarcoded = barcoded.stableKey(receiptKey: "some_receipt", index: 0)
        let firstUnbarcoded = unbarcoded.stableKey(receiptKey: "some_receipt", index: 2)
        for _ in 0..<10 {
            #expect(barcoded.stableKey(receiptKey: "some_receipt", index: 0) == firstBarcoded)
            #expect(unbarcoded.stableKey(receiptKey: "some_receipt", index: 2) == firstUnbarcoded)
        }
    }
}
