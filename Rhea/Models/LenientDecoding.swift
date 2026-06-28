import Foundation

/// Lenient decoding helpers.
///
/// Vision models frequently ignore "string" vs "number" instructions — e.g. emitting a
/// numeric `storeNumber`/`barcode`, or quoting a price as a string. Strict `JSONDecoder`
/// throws `typeMismatch` on the first such field and fails the entire receipt. These
/// helpers coerce the common shapes (String / Int / Decimal / Bool / null) so one
/// off-type field doesn't sink an otherwise good extraction.
extension KeyedDecodingContainer {

    /// Decodes an optional string, accepting numbers/bools and coercing them to text.
    func lenientString(_ key: Key) -> String? {
        guard contains(key), (try? decodeNil(forKey: key)) != true else { return nil }
        if let s = try? decode(String.self, forKey: key) {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        // Int before Decimal so integer barcodes/store numbers stay exact (no ".0").
        if let i = try? decode(Int.self, forKey: key) { return String(i) }
        if let d = try? decode(Decimal.self, forKey: key) { return NSDecimalNumber(decimal: d).stringValue }
        if let b = try? decode(Bool.self, forKey: key) { return String(b) }
        return nil
    }

    /// Decodes a required string, falling back to `def` when missing or uncoercible.
    func lenientString(_ key: Key, default def: String) -> String {
        lenientString(key) ?? def
    }

    /// Decodes an optional decimal, accepting numbers or numeric strings ("$1,234.50").
    func lenientDecimal(_ key: Key) -> Decimal? {
        guard contains(key), (try? decodeNil(forKey: key)) != true else { return nil }
        if let d = try? decode(Decimal.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key) {
            let cleaned = s.replacingOccurrences(of: "$", with: "")
                           .replacingOccurrences(of: ",", with: "")
                           .trimmingCharacters(in: .whitespacesAndNewlines)
            return Decimal(string: cleaned)
        }
        return nil
    }

    /// Decodes a required decimal, falling back to `def` when missing or uncoercible.
    func lenientDecimal(_ key: Key, default def: Decimal) -> Decimal {
        lenientDecimal(key) ?? def
    }
}
