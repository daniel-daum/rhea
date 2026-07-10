import Foundation

/// Shared currency/date formatting, so display formatting is defined once instead of as local
/// helpers per view.
enum AppFormatters {
    static func currency(_ value: Decimal) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = .current
        return fmt.string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    /// Formats an ISO-8601 date string (as stored on `ExtractedReceipt.date`) for display;
    /// falls back to the raw string if it doesn't parse.
    static func shortDate(fromISO iso: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
