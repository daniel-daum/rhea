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

    // Kept in sync with db/schema.sql (authoritative; also defines analysis views).
    // NOTE (v2): the schema changed incompatibly (purchase_date DATE, raw_name, line_type,
    // generated columns). Databases created by the old prototype should be dropped and
    // recreated — the dataset is being rebuilt from scratch anyway.
    private static let createTablesSQL = """
    CREATE TABLE IF NOT EXISTS products (
        id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        common_name  TEXT NOT NULL UNIQUE,
        category     TEXT,
        is_organic   BOOLEAN NOT NULL DEFAULT FALSE,
        default_unit TEXT CHECK (default_unit IN ('lb','each')),
        notes        TEXT,
        created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
    );
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
    CREATE INDEX IF NOT EXISTS idx_receipts_chain_date ON receipts (chain, purchase_date);
    CREATE TABLE IF NOT EXISTS receipt_line_items (
        id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        receipt_id      UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
        line_no         INT  NOT NULL,
        item_code       TEXT,
        raw_name        TEXT NOT NULL,
        ai_common_name  TEXT,
        common_name     TEXT,
        product_id      BIGINT REFERENCES products(id),
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
    CREATE INDEX IF NOT EXISTS idx_li_common_name ON receipt_line_items (common_name);
    CREATE INDEX IF NOT EXISTS idx_li_receipt     ON receipt_line_items (receipt_id);
    """

    private static func makeInsertSQL(_ r: Receipt) -> String {
        let e   = r.extracted!
        let id  = r.id.uuidString
        let receiptKey = r.naturalKey

        let overallConf = e.overallConfidence.map { String(format: "%.2f", $0) } ?? "NULL"
        let date = String(e.date.prefix(10))                    // YYYY-MM-DD
        let ts   = e.date.count > 10 ? s(e.date) : "NULL"       // full timestamp if present
        let sql_receipt = """
        INSERT INTO receipts (id,receipt_key,merchant,chain,store_number,store_address,purchase_date,purchased_at,receipt_number,total,tax,payment_method,confirmed,source,source_file,overall_confidence)
        VALUES (\(s(id)),\(s(receiptKey)),\(s(e.merchant)),\(n(e.chain)),\(n(e.storeNumber)),\(n(e.storeAddress)),\(s(date)),\(ts),\(n(e.receiptNumber)),\(fmt(e.total)),\(e.tax.map { fmt($0) } ?? "NULL"),\(n(e.paymentMethod)),\(r.confirmed ? "TRUE" : "FALSE"),'rhea',\(s(r.sourceURL.lastPathComponent)),\(overallConf))
        ON CONFLICT (receipt_key) DO UPDATE SET
          merchant=EXCLUDED.merchant,chain=EXCLUDED.chain,store_number=EXCLUDED.store_number,
          store_address=EXCLUDED.store_address,purchase_date=EXCLUDED.purchase_date,purchased_at=EXCLUDED.purchased_at,
          receipt_number=EXCLUDED.receipt_number,total=EXCLUDED.total,tax=EXCLUDED.tax,
          payment_method=EXCLUDED.payment_method,confirmed=EXCLUDED.confirmed,
          source_file=EXCLUDED.source_file,overall_confidence=EXCLUDED.overall_confidence,updated_at=now();
        DELETE FROM receipt_line_items WHERE receipt_id=(SELECT id FROM receipts WHERE receipt_key=\(s(receiptKey)));
        """

        guard !e.lineItems.isEmpty else { return sql_receipt }

        let rows = e.lineItems.enumerated().map { (index, item) -> String in
            let effectivePaid = item.pricePaid ?? item.lineTotal
            let itemConf = item.confidence.map { String(format: "%.2f", $0) } ?? "NULL"
            return """
            ((SELECT id FROM receipts WHERE receipt_key=\(s(receiptKey))),\(index + 1),\(n(item.barcode)),\(s(item.name)),\(n(item.aiCommonName)),\(n(item.userCommonName)),\(n(item.category)),\(s(item.effectiveLineType)),\
            \(item.quantity.map   { fmt($0, d: 3) } ?? "NULL"),\
            \(item.unitPrice.map  { fmt($0, d: 4) } ?? "NULL"),\
            \(item.weightLbs.map  { fmt($0, d: 4) } ?? "NULL"),\
            \(item.pricePerLb.map { fmt($0, d: 4) } ?? "NULL"),\
            \(item.listPrice.map  { fmt($0) }       ?? "NULL"),\
            \(effectivePaid.map   { fmt($0) }       ?? "NULL"),\
            \(itemConf))
            """
        }.joined(separator: ",\n")

        return sql_receipt + """
        INSERT INTO receipt_line_items(receipt_id,line_no,item_code,raw_name,ai_common_name,common_name,category,line_type,quantity,unit_price,weight_lbs,price_per_lb,list_price,price_paid,item_confidence)
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
