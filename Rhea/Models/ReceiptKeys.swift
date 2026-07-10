import Foundation

/// Slugifies a key component: lowercased, non-alphanumerics collapsed to single dashes.
/// e.g. "TRADER JOE'S" -> "trader-joe-s".
func slugComponent(_ raw: String) -> String {
    let mapped = raw.lowercased().map { ($0.isLetter || $0.isNumber) ? $0 : "-" }
    return String(mapped)
        .split(separator: "-", omittingEmptySubsequences: true)
        .joined(separator: "-")
}

public extension Receipt {
    /// Prefixed, stable public identifier derived from the UUID.
    var publicID: String {
        "rhea_receipt_id_" + id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// Short, stable fallback receipt number derived from the receipt UUID.
    /// Used when the model cannot read the barcode or receipt number from the image.
    var generatedReceiptNumber: String {
        let hex = id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8).uppercased()
        return "RHR-\(hex)"
    }

    /// Human-readable natural key for DB analysis:
    /// `chain_storeNumber_date_receiptNumber` (slugified).
    /// When no receipt number is extracted, the UUID-derived generatedReceiptNumber is used
    /// to guarantee uniqueness across same-merchant same-date purchases.
    /// Falls back to publicID when chain + at least one other component are unavailable.
    var naturalKey: String {
        guard let e = extracted else { return publicID }
        let chain   = e.chain.map(slugComponent) ?? ""
        let store   = e.storeNumber.map(slugComponent) ?? ""
        let date    = String(e.date.prefix(10))                       // YYYY-MM-DD
        // Prefer the extracted receipt number; fall back to UUID-derived for uniqueness
        let receipt = e.receiptNumber.map(slugComponent) ?? slugComponent(generatedReceiptNumber)
        let parts   = [chain, store, date, receipt].filter { !$0.isEmpty }
        guard !chain.isEmpty, parts.count >= 2 else { return publicID }
        return parts.joined(separator: "_")
    }
}

public extension LineItem {
    /// Stable per-item key: `barcode_<barcode>` when a barcode exists,
    /// otherwise `<receiptKey>_itemNN` (1-based, zero-padded).
    func stableKey(receiptKey: String, index: Int) -> String {
        if let bc = barcode?.trimmingCharacters(in: .whitespacesAndNewlines), !bc.isEmpty {
            return "barcode_" + slugComponent(bc)
        }
        return "\(receiptKey)_item\(String(format: "%02d", index + 1))"
    }
}
