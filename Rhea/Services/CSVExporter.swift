import Foundation

/// Bulk-exports all confirmed receipts to ~/Documents/Rhea/receipts.csv.
/// Column order mirrors the user's hand-built spreadsheet.
enum CSVExporter {

    static var outputURL: URL {
        let dir = URL.documentsDirectory
            .appending(path: "Rhea", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "receipts.csv")
    }

    @discardableResult
    static func exportAll(_ receipts: [Receipt]) throws -> URL {
        let exportable = receipts.filter { $0.confirmed && $0.extracted != nil }
        // One row per line item (flat, like the hand-built CSV)
        var rows: [String] = [header]
        for receipt in exportable {
            let e = receipt.extracted!
            let receiptKey = receipt.naturalKey
            for (index, item) in e.lineItems.enumerated() {
                rows.append(makeRow(receipt: receipt, extracted: e, item: item,
                                    receiptKey: receiptKey, index: index))
            }
        }
        let csv = rows.joined(separator: "\n")
        try Data(csv.utf8).write(to: outputURL, options: .atomic)
        return outputURL
    }

    // MARK: - Column layout

    private static let header =
        "RECEIPT_ID,RECEIPT_KEY,ITEM_KEY," +
        "RECEIPT_SCAN,CHAIN,STORE_NUMBER,STORE_ADDRESS,DATE,RECEIPT_NUMBER," +
        "RECEIPT_CONFIDENCE,CATEGORY,CODE,ITEM,AI_COMMON_NAME,COMMON_NAME,LINE_TYPE," +
        "WEIGHT_LB,PRICE_PER_LB,QUANTITY,PRICE_PER_UNIT,LIST_PRICE,PRICE_PAID,ITEM_CONFIDENCE"

    private static func makeRow(receipt: Receipt, extracted e: ExtractedReceipt,
                                item: LineItem, receiptKey: String, index: Int) -> String {
        let fields: [String] = [
            q(receipt.publicID),                                        // RECEIPT_ID
            q(receiptKey),                                              // RECEIPT_KEY
            q(item.stableKey(receiptKey: receiptKey, index: index)),    // ITEM_KEY
            "YES",                                                      // RECEIPT_SCAN
            q(e.chain ?? chainFromMerchant(e.merchant)),                // CHAIN
            q(e.storeNumber ?? ""),                                     // STORE_NUMBER
            q(e.storeAddress ?? ""),                                    // STORE_ADDRESS
            q(e.date.prefix(10).description),                          // DATE (YYYY-MM-DD)
            q(e.receiptNumber ?? ""),                                   // RECEIPT_NUMBER
            e.overallConfidence.map { String(format: "%.2f", $0) } ?? "",  // RECEIPT_CONFIDENCE
            q(item.category ?? ""),                                     // CATEGORY
            q(item.barcode ?? ""),                                      // CODE
            q(item.name),                                               // ITEM
            q(item.aiCommonName ?? ""),                                 // AI_COMMON_NAME
            q(item.userCommonName ?? ""),                               // COMMON_NAME (user)
            q(item.effectiveLineType),                                  // LINE_TYPE
            item.weightLbs.map   { "\($0)" } ?? "",                    // WEIGHT_LB
            item.pricePerLb.map  { "\($0)" } ?? "",                    // PRICE_PER_LB
            item.quantity.map    { "\($0)" } ?? "",                    // QUANTITY
            item.unitPrice.map   { "\($0)" } ?? "",                    // PRICE_PER_UNIT
            item.listPrice.map   { "\($0)" } ?? "",                    // LIST_PRICE
            (item.pricePaid ?? item.lineTotal).map { "\($0)" } ?? "",  // PRICE_PAID
            item.confidence.map { String(format: "%.2f", $0) } ?? "",  // ITEM_CONFIDENCE
        ]
        return fields.joined(separator: ",")
    }

    private static func chainFromMerchant(_ merchant: String) -> String {
        let upper = merchant.uppercased()
        for chain in ["SAFEWAY", "TRADER JOE", "WHOLE FOODS", "COSTCO", "TARGET", "WALMART"] {
            if upper.contains(chain) { return chain }
        }
        return merchant.uppercased()
    }

    private static func q(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
