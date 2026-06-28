import Foundation

// MARK: - Config

struct PostgresConfig: Codable, Equatable {
    var host:     String = "localhost"
    var port:     Int    = 5432
    var dbname:   String = ""
    var user:     String = ""
    var password: String = ""

    var isConfigured: Bool { !dbname.trimmingCharacters(in: .whitespaces).isEmpty
                          && !user.trimmingCharacters(in: .whitespaces).isEmpty }
}

// MARK: - Errors

enum PostgresError: LocalizedError {
    case notConfigured
    case psqlNotFound
    case psqlFailed(String)
    case noRecordsToExport

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Enter a database name and username in the Postgres settings."
        case .psqlNotFound:
            return "psql not found. Install via Homebrew (brew install postgresql) or Postgres.app."
        case .psqlFailed(let msg):
            return msg.trimmingCharacters(in: .whitespacesAndNewlines)
        case .noRecordsToExport:
            return "No confirmed receipts to export."
        }
    }
}

// MARK: - Store

enum PostgresStore {

    /// Checks that psql can reach the database.
    static func testConnection(config: PostgresConfig) async throws {
        guard config.isConfigured else { throw PostgresError.notConfigured }
        _ = try await run("SELECT 1;", config: config)
    }

    /// Creates tables if needed and upserts every confirmed receipt.
    static func insertAll(_ receipts: [Receipt], config: PostgresConfig) async throws -> Int {
        guard config.isConfigured else { throw PostgresError.notConfigured }
        let exportable = receipts.filter { $0.confirmed && $0.extracted != nil }
        guard !exportable.isEmpty else { throw PostgresError.noRecordsToExport }

        var sql = createTablesSQL
        for r in exportable { sql += "\n" + makeInsertSQL(r) }
        _ = try await run(sql, config: config)
        return exportable.count
    }

    // MARK: - SQL generation

    private static let createTablesSQL = """
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
    -- Add new columns to receipts if upgrading from earlier schema
    ALTER TABLE receipts ADD COLUMN IF NOT EXISTS receipt_key TEXT;
    ALTER TABLE receipts ADD COLUMN IF NOT EXISTS chain TEXT;
    ALTER TABLE receipts ADD COLUMN IF NOT EXISTS store_number TEXT;
    ALTER TABLE receipts ADD COLUMN IF NOT EXISTS store_address TEXT;
    ALTER TABLE receipts ADD COLUMN IF NOT EXISTS receipt_number TEXT;
    -- Add new columns to receipt_line_items if upgrading
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS item_key TEXT;
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS ai_common_name TEXT;
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS common_name TEXT;
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS category TEXT;
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS barcode TEXT;
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS weight_lbs NUMERIC(10,4);
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS price_per_lb NUMERIC(10,4);
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS list_price NUMERIC(10,2);
    ALTER TABLE receipt_line_items ADD COLUMN IF NOT EXISTS price_paid NUMERIC(10,2);
    """

    private static func makeInsertSQL(_ r: Receipt) -> String {
        let e   = r.extracted!
        let id  = r.id.uuidString
        let receiptKey = r.naturalKey

        let sql_receipt = """
        INSERT INTO receipts (id,receipt_key,merchant,chain,store_number,store_address,date,receipt_number,total,tax,payment_method,confirmed,source_file)
        VALUES (\(s(id)),\(s(receiptKey)),\(s(e.merchant)),\(n(e.chain)),\(n(e.storeNumber)),\(n(e.storeAddress)),\(s(e.date)),\(n(e.receiptNumber)),\(fmt(e.total)),\(e.tax.map { fmt($0) } ?? "NULL"),\(n(e.paymentMethod)),\(r.confirmed ? "TRUE" : "FALSE"),\(s(r.sourceURL.lastPathComponent)))
        ON CONFLICT (id) DO UPDATE SET
          receipt_key=EXCLUDED.receipt_key,merchant=EXCLUDED.merchant,chain=EXCLUDED.chain,store_number=EXCLUDED.store_number,
          store_address=EXCLUDED.store_address,date=EXCLUDED.date,receipt_number=EXCLUDED.receipt_number,
          total=EXCLUDED.total,tax=EXCLUDED.tax,payment_method=EXCLUDED.payment_method,confirmed=EXCLUDED.confirmed;
        DELETE FROM receipt_line_items WHERE receipt_id=\(s(id));
        """

        guard !e.lineItems.isEmpty else { return sql_receipt }

        let rows = e.lineItems.enumerated().map { (index, item) -> String in
            let effectivePaid = item.pricePaid ?? item.lineTotal
            let itemKey = item.stableKey(receiptKey: receiptKey, index: index)
            return """
            (\(s(id)),\(s(itemKey)),\(s(item.name)),\(n(item.aiCommonName)),\(n(item.userCommonName)),\(n(item.category)),\(n(item.barcode)),\
            \(item.quantity.map   { fmt($0, d: 3) } ?? "NULL"),\
            \(item.unitPrice.map  { fmt($0, d: 4) } ?? "NULL"),\
            \(item.weightLbs.map  { fmt($0, d: 4) } ?? "NULL"),\
            \(item.pricePerLb.map { fmt($0, d: 4) } ?? "NULL"),\
            \(item.listPrice.map  { fmt($0) }       ?? "NULL"),\
            \(effectivePaid.map   { fmt($0) }       ?? "NULL"),\
            \(item.lineTotal.map  { fmt($0) }       ?? "NULL"))
            """
        }.joined(separator: ",\n")

        return sql_receipt + """
        INSERT INTO receipt_line_items(receipt_id,item_key,name,ai_common_name,common_name,category,barcode,quantity,unit_price,weight_lbs,price_per_lb,list_price,price_paid,line_total)
        VALUES \(rows);
        """
    }

    // SQL literal helpers
    private static func s(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "''") + "'"
    }
    private static func n(_ str: String?) -> String {
        str.map { s($0) } ?? "NULL"
    }
    private static func fmt(_ d: Decimal, d decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", (d as NSDecimalNumber).doubleValue)
    }

    // MARK: - psql subprocess

    private static func run(_ sql: String, config: PostgresConfig) async throws -> String {
        let psql = try findPSQL()

        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "rv_\(UUID().uuidString).sql")
        try Data(sql.utf8).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        return try await withCheckedThrowingContinuation { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: psql)
            proc.arguments = [
                "-h", config.host,
                "-p", "\(config.port)",
                "-U", config.user,
                "-d", config.dbname,
                "-f", tmp.path(percentEncoded: false),
            ]
            var env = ProcessInfo.processInfo.environment
            if !config.password.isEmpty { env["PGPASSWORD"] = config.password }
            proc.environment = env

            let out = Pipe(), err = Pipe()
            proc.standardOutput = out
            proc.standardError  = err

            proc.terminationHandler = { p in
                let outStr = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let errStr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if p.terminationStatus == 0 {
                    continuation.resume(returning: outStr)
                } else {
                    continuation.resume(throwing: PostgresError.psqlFailed(errStr.isEmpty ? outStr : errStr))
                }
            }
            do { try proc.run() }
            catch { continuation.resume(throwing: error) }
        }
    }

    private static func findPSQL() throws -> String {
        var candidates = [
            "/opt/homebrew/bin/psql",
            "/usr/local/bin/psql",
            "/usr/bin/psql",
        ]
        let pgApp = "/Applications/Postgres.app/Contents/Versions"
        if let versions = try? FileManager.default.contentsOfDirectory(atPath: pgApp) {
            candidates += versions.sorted().reversed().map { "\(pgApp)/\($0)/bin/psql" }
        }
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        throw PostgresError.psqlNotFound
    }
}
