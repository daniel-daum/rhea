import Foundation

/// Exports confirmed receipts as idempotent SQL INSERT statements to ~/Documents/Rhea/receipts.sql.
/// Run the output against any Postgres database: psql -d <dbname> -f receipts.sql
actor PostgresSQLExporter: PersistenceStore {

    nonisolated let fileURL: URL
    nonisolated let storeDescription: String

    init() {
        let dir = URL.documentsDirectory
            .appending(path: "Rhea", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "receipts.sql")
        self.fileURL          = url
        self.storeDescription = url.path(percentEncoded: false)
    }

    // MARK: PersistenceStore

    func save(_ receipt: Receipt) async throws {
        guard let e = receipt.extracted else { return }
        var blocks = try loadBlocks()
        blocks.removeAll { $0.id == receipt.id.uuidString }
        blocks.append(makeBlock(receipt, extracted: e))
        try writeBlocks(blocks)
    }

    func delete(id: UUID) async throws {
        var blocks = try loadBlocks()
        blocks.removeAll { $0.id == id.uuidString }
        try writeBlocks(blocks)
    }

    func load() async throws -> [Receipt] { [] }

    // MARK: - SQL generation

    private struct Block {
        let id: String
        let sql: String
    }

    private func makeBlock(_ r: Receipt, extracted e: ExtractedReceipt) -> Block {
        let id   = r.id.uuidString
        let key  = r.naturalKey
        let date = String(e.date.prefix(10))                    // YYYY-MM-DD
        let ts   = e.date.count > 10 ? s(e.date) : "NULL"       // full timestamp if present
        let tot  = formatDecimal(e.total)
        let tax  = e.tax.map { formatDecimal($0) } ?? "NULL"
        let pay  = e.paymentMethod.map { s($0) } ?? "NULL"
        let src  = s(r.sourceURL.lastPathComponent)
        let conf = r.confirmed ? "TRUE" : "FALSE"
        let oc   = e.overallConfidence.map { String(format: "%.2f", $0) } ?? "NULL"
        let chain = e.chain.map { s($0) } ?? "NULL"
        let stNo  = e.storeNumber.map { s($0) } ?? "NULL"
        let stAd  = e.storeAddress.map { s($0) } ?? "NULL"
        let rcNo  = e.receiptNumber.map { s($0) } ?? "NULL"

        var lines: [String] = [
            "-- Receipt \(id)",
            "INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,",
            "                      purchase_date, purchased_at, receipt_number, total, tax,",
            "                      payment_method, confirmed, source, source_file, overall_confidence)",
            "VALUES (\(s(id)), \(s(key)), \(s(e.merchant)), \(chain), \(stNo), \(stAd),",
            "        \(s(date)), \(ts), \(rcNo), \(tot), \(tax),",
            "        \(pay), \(conf), 'rhea', \(src), \(oc))",
            "ON CONFLICT (receipt_key) DO UPDATE SET",
            "    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,",
            "    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,",
            "    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,",
            "    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total, tax = EXCLUDED.tax,",
            "    payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed,",
            "    source_file = EXCLUDED.source_file, overall_confidence = EXCLUDED.overall_confidence,",
            "    updated_at = now();",
        ]

        if !e.lineItems.isEmpty {
            lines.append("DELETE FROM receipt_line_items WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_key = \(s(key)));")
            let rows = e.lineItems.enumerated().map { (index, item) -> String in
                let code = item.barcode.map { s($0) } ?? "NULL"
                let ai   = item.aiCommonName.map { s($0) } ?? "NULL"
                let cn   = item.userCommonName.map { s($0) } ?? "NULL"
                let cat  = item.category.map { s($0) } ?? "NULL"
                let lt   = s(item.effectiveLineType)
                let qty  = item.quantity.map   { formatDecimal($0, decimals: 3) } ?? "NULL"
                let unit = item.unitPrice.map  { formatDecimal($0, decimals: 4) } ?? "NULL"
                let wt   = item.weightLbs.map  { formatDecimal($0, decimals: 4) } ?? "NULL"
                let plb  = item.pricePerLb.map { formatDecimal($0, decimals: 4) } ?? "NULL"
                let list = item.listPrice.map  { formatDecimal($0) } ?? "NULL"
                let paid = item.effectivePricePaid.map { formatDecimal($0) } ?? "NULL"
                let ic   = item.confidence.map { String(format: "%.2f", $0) } ?? "NULL"
                return "    ((SELECT id FROM receipts WHERE receipt_key = \(s(key))), \(index + 1), \(code), \(s(item.name)), \(ai), \(cn), \(cat), \(lt), \(qty), \(unit), \(wt), \(plb), \(list), \(paid), \(ic))"
            }.joined(separator: ",\n")
            lines.append(
                "INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name, common_name, category, line_type, quantity, unit_price, weight_lbs, price_per_lb, list_price, price_paid, item_confidence)\nVALUES\n\(rows);"
            )
        }

        return Block(id: id, sql: lines.joined(separator: "\n"))
    }

    // MARK: - File I/O

    private func loadBlocks() throws -> [Block] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var result: [Block] = []
        var currentID: String?
        var currentLines: [String] = []

        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("-- Receipt ") {
                if let id = currentID {
                    result.append(Block(id: id, sql: currentLines.joined(separator: "\n")))
                }
                currentID    = String(line.dropFirst("-- Receipt ".count)).trimmingCharacters(in: .whitespaces)
                currentLines = [line]
            } else if currentID != nil {
                currentLines.append(line)
            }
        }
        if let id = currentID { result.append(Block(id: id, sql: currentLines.joined(separator: "\n"))) }
        return result
    }

    private func writeBlocks(_ blocks: [Block]) throws {
        let ts = ISO8601DateFormatter().string(from: Date())
        let header = """
        -- Rhea SQL Export
        -- Generated: \(ts)
        -- Run: psql -d <your_database> -f receipts.sql

        """
        let body = blocks.map(\.sql).joined(separator: "\n\n")
        try Data((header + body).utf8).write(to: fileURL, options: .atomic)
    }

    // MARK: - Helpers

    private func s(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "''") + "'"
    }

    private func formatDecimal(_ d: Decimal, decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", (d as NSDecimalNumber).doubleValue)
    }
}

// MARK: - Postgres schema constant (used by SettingsView)

// Kept in sync with db/schema.sql (the authoritative copy, which also defines
// the products dimension and analysis views). Shown in SettingsView.
let postgresSchema = """
-- Full schema (products dimension + analysis views) lives in db/schema.sql.
CREATE TABLE IF NOT EXISTS receipts (
    id              UUID PRIMARY KEY,
    receipt_key     TEXT NOT NULL UNIQUE,
    merchant        TEXT NOT NULL,
    chain           TEXT,
    store_number    TEXT,
    store_address   TEXT,
    purchase_date   DATE NOT NULL,
    purchased_at    TIMESTAMPTZ,
    receipt_number  TEXT,
    total           NUMERIC(10,2) NOT NULL,
    tax             NUMERIC(10,2),
    payment_method  TEXT,
    confirmed       BOOLEAN NOT NULL DEFAULT FALSE,
    source          TEXT NOT NULL DEFAULT 'rhea'
                    CHECK (source IN ('baseline','rhea','manual')),
    source_file     TEXT,
    overall_confidence NUMERIC(3,2),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS receipt_line_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id      UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    line_no         INT  NOT NULL,
    item_code       TEXT,
    raw_name        TEXT NOT NULL,
    ai_common_name  TEXT,
    common_name     TEXT,
    product_id      BIGINT,
    category        TEXT,
    line_type       TEXT NOT NULL DEFAULT 'item'
                    CHECK (line_type IN ('item','deposit','fee','refund','discount','non_grocery')),
    quantity        NUMERIC(10,3),
    unit_price      NUMERIC(10,4),
    weight_lbs      NUMERIC(10,4),
    price_per_lb    NUMERIC(10,4),
    list_price      NUMERIC(10,2),
    price_paid      NUMERIC(10,2),
    item_confidence NUMERIC(3,2),
    effective_unit  TEXT GENERATED ALWAYS AS (
        CASE WHEN weight_lbs IS NOT NULL AND weight_lbs > 0 THEN 'lb' ELSE 'each' END
    ) STORED,
    effective_unit_price NUMERIC(12,4) GENERATED ALWAYS AS (
        CASE
            WHEN weight_lbs IS NOT NULL AND weight_lbs > 0 THEN price_paid / weight_lbs
            WHEN quantity   IS NOT NULL AND quantity   > 0 THEN price_paid / quantity
            ELSE price_paid
        END
    ) STORED,
    UNIQUE (receipt_id, line_no)
);
"""
