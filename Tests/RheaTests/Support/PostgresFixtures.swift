import Foundation
@testable import Rhea

/// Synthetic receipts for `PostgresSQLGoldenTests`. Fixed UUIDs and field values keep the
/// generated SQL byte-for-byte reproducible so it can be diffed against a golden `.sql` file.
enum PostgresFixtures {

    /// A "normal" receipt exercising decimal formatting (3/4 decimal columns, whole-number
    /// prices), a mix of present/absent optional fields, and a non-"item" line type.
    static func fullReceipt() -> Receipt {
        Receipt(
            id: UUID(uuidString: "0BADF00D-CAFE-4000-8000-000000000001")!,
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic/golden_full_receipt.pdf"),
            status: .done,
            extracted: ExtractedReceipt(
                merchant: "Trader Joe's #42",
                chain: "TRADER JOE'S",
                storeNumber: "042",
                storeAddress: "123 Main St, Springfield",
                date: "2026-03-14T08:30:00Z",
                receiptNumber: "R-1001",
                total: Decimal(string: "42.37")!,
                tax: Decimal(string: "3.12")!,
                paymentMethod: "VISA •••• 4242",
                lineItems: [
                    LineItem(
                        name: "O'Brien's Chips",
                        aiCommonName: "potato chips",
                        category: "GROCERY",
                        barcode: "012345678905",
                        quantity: Decimal(2),
                        unitPrice: Decimal(string: "3.5")!,
                        listPrice: Decimal(string: "7.00")!,
                        pricePaid: Decimal(string: "7.00")!,
                        confidence: 0.95
                    ),
                    LineItem(
                        name: "Bananas",
                        userCommonName: "bananas",
                        weightLbs: Decimal(string: "1.25")!,
                        pricePerLb: Decimal(string: "2.00")!,
                        pricePaid: Decimal(string: "2.50")!
                    ),
                    LineItem(name: "Plain Item"),
                    LineItem(name: "CRV Deposit", pricePaid: Decimal(string: "0.05")!, lineType: "deposit"),
                ],
                overallConfidence: 0.87
            ),
            confirmed: true
        )
    }

    /// Exercises escaping: an already-doubled quote, embedded double quotes, a Windows-style
    /// backslash path, unicode (accented letter + emoji), and a literal newline inside a value.
    static func escapingReceipt() -> Receipt {
        Receipt(
            id: UUID(uuidString: "0BADF00D-CAFE-4000-8000-000000000002")!,
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic/golden_escaping_receipt.pdf"),
            status: .done,
            extracted: ExtractedReceipt(
                merchant: "O''Brien's Grocery",
                chain: "O'BRIEN'S",
                storeAddress: "123 Main St\nApt #4",
                date: "2026-05-01",
                receiptNumber: "R-\"Weekly\"-9",
                total: Decimal(string: "10.00")!,
                lineItems: [
                    LineItem(
                        name: "Café specialty ☕ \"Doorbuster\"",
                        quantity: Decimal(1),
                        unitPrice: Decimal(string: "10.00")!,
                        listPrice: Decimal(string: "10.00")!,
                        pricePaid: Decimal(string: "10.00")!
                    ),
                    LineItem(name: "C:\\Users\\test\\file.txt", barcode: "5'0\\1"),
                ]
            ),
            confirmed: true
        )
    }

    /// Only the required fields are set; every optional receipt- and item-level column should
    /// come out `NULL`, and the omitted `lineType` should default to `'item'`.
    static func minimalReceipt() -> Receipt {
        Receipt(
            id: UUID(uuidString: "0BADF00D-CAFE-4000-8000-000000000003")!,
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic/golden_minimal_receipt.pdf"),
            status: .done,
            extracted: ExtractedReceipt(
                merchant: "Minimal Mart",
                chain: "MINIMAL MART",
                date: "2026-01-02",
                receiptNumber: "R-1",
                total: Decimal(string: "5.00")!,
                lineItems: [LineItem(name: "Plain Item")]
            ),
            confirmed: true
        )
    }
}
