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
    /// Prefixed, stable public identifier derived from the UUID (e.g. `rcpt_ab12…`).
    var publicID: String {
        "rcpt_" + id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// Human-readable natural key chained to the UUID, for DB analysis:
    /// `chain_storeNumber_date_receiptNumber` (slugified). Falls back to `publicID`
    /// when essential parts (at minimum chain + one other) are missing.
    var naturalKey: String {
        guard let e = extracted else { return publicID }
        let chain   = e.chain.map(slugComponent) ?? ""
        let store   = e.storeNumber.map(slugComponent) ?? ""
        let date    = String(e.date.prefix(10))                 // YYYY-MM-DD
        let receipt = e.receiptNumber.map(slugComponent) ?? ""
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
