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
        let tot  = formatDecimal(e.total)
        let tax  = e.tax.map { formatDecimal($0) } ?? "NULL"
        let pay  = e.paymentMethod.map { s($0) } ?? "NULL"
        let src  = s(r.sourceURL.lastPathComponent)
        let conf = r.confirmed ? "TRUE" : "FALSE"

        var lines: [String] = [
            "-- Receipt \(id)",
            "INSERT INTO receipts (id, merchant, date, total, tax, payment_method, confirmed, source_file)",
            "VALUES (\(s(id)), \(s(e.merchant)), \(s(e.date)), \(tot), \(tax), \(pay), \(conf), \(src))",
            "ON CONFLICT (id) DO UPDATE SET",
            "    merchant = EXCLUDED.merchant, date = EXCLUDED.date, total = EXCLUDED.total,",
            "    tax = EXCLUDED.tax, payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed;",
        ]

        if !e.lineItems.isEmpty {
            lines.append("DELETE FROM receipt_line_items WHERE receipt_id = \(s(id));")
            let rows = e.lineItems.map { item -> String in
                let qty  = item.quantity.map  { formatDecimal($0, decimals: 3) } ?? "NULL"
                let unit = item.unitPrice.map { formatDecimal($0) } ?? "NULL"
                let tot2 = item.lineTotal.map { formatDecimal($0) } ?? "NULL"
                return "    (\(s(id)), \(s(item.name)), \(qty), \(unit), \(tot2))"
            }.joined(separator: ",\n")
            lines.append(
                "INSERT INTO receipt_line_items (receipt_id, name, quantity, unit_price, line_total)\nVALUES\n\(rows);"
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

let postgresSchema = """
CREATE TABLE IF NOT EXISTS receipts (
    id              UUID PRIMARY KEY,
    receipt_key     TEXT,
    merchant        TEXT NOT NULL,
    chain           TEXT,
    store_number    TEXT,
    store_address   TEXT,
    date            TEXT NOT NULL,
    receipt_number  TEXT,
    total           NUMERIC(10,2) NOT NULL,
    tax             NUMERIC(10,2),
    payment_method  TEXT,
    confirmed       BOOLEAN DEFAULT FALSE,
    source_file     TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS receipt_line_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id      UUID REFERENCES receipts(id) ON DELETE CASCADE,
    item_key        TEXT,
    name            TEXT NOT NULL,
    ai_common_name  TEXT,
    common_name     TEXT,
    category        TEXT,
    barcode         TEXT,
    quantity        NUMERIC(10,3),
    unit_price      NUMERIC(10,4),
    weight_lbs      NUMERIC(10,4),
    price_per_lb    NUMERIC(10,4),
    list_price      NUMERIC(10,2),
    price_paid      NUMERIC(10,2),
    line_total      NUMERIC(10,2)
);
"""
