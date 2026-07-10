import Testing
import Foundation
@testable import Rhea

/// Golden-file coverage for `PostgresStore.makeInsertSQL` and `PostgresSQLExporter.makeBlock` —
/// the two places that hand-build SQL via string interpolation with only quote-doubling
/// (`s()`/`n()`). A quoting/escaping bug here is a data-corruption or SQL-injection bug, so the
/// full generated statement is diffed against a checked-in `.sql` file rather than spot-checked.
///
/// Regenerating a golden file after an intentional formatting change:
/// 1. Temporarily change the `#expect(actual == golden)` call below to
///    `print(actual)` (or break in the debugger and copy the `actual` value), run the test.
/// 2. Paste the printed value into the corresponding file under `Tests/Fixtures/Golden/`,
///    preserving the exact whitespace/newlines (no trailing newline beyond the file's final one).
/// 3. Re-run the test to confirm it now passes, and read the diff in the PR — a golden file
///    changing unexpectedly is exactly what this suite exists to catch.
struct PostgresSQLGoldenTests {

    private static var fixturesBundle: Bundle { Bundle(for: StubExtractionServer.self) }

    private static func golden(_ name: String) throws -> String {
        let url = try #require(fixturesBundle.url(forResource: name, withExtension: "sql"))
        return try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .newlines)
    }

    // MARK: - PostgresStore.makeInsertSQL golden snapshots

    @Test func storeGeneratesGoldenSQLForFullReceipt() throws {
        let actual = PostgresStore.makeInsertSQL(PostgresFixtures.fullReceipt())
        #expect(actual == (try Self.golden("postgres_store_full")))
    }

    @Test func storeGeneratesGoldenSQLForEscapingReceipt() throws {
        let actual = PostgresStore.makeInsertSQL(PostgresFixtures.escapingReceipt())
        #expect(actual == (try Self.golden("postgres_store_escaping")))
    }

    @Test func storeGeneratesGoldenSQLForMinimalReceipt() throws {
        let actual = PostgresStore.makeInsertSQL(PostgresFixtures.minimalReceipt())
        #expect(actual == (try Self.golden("postgres_store_minimal")))
    }

    // MARK: - PostgresSQLExporter.makeBlock golden snapshots

    @Test func exporterGeneratesGoldenSQLForFullReceipt() async throws {
        let receipt = PostgresFixtures.fullReceipt()
        let actual = await PostgresSQLExporter().makeBlock(receipt, extracted: receipt.extracted!).sql
        #expect(actual == (try Self.golden("postgres_exporter_full")))
    }

    @Test func exporterGeneratesGoldenSQLForEscapingReceipt() async throws {
        let receipt = PostgresFixtures.escapingReceipt()
        let actual = await PostgresSQLExporter().makeBlock(receipt, extracted: receipt.extracted!).sql
        #expect(actual == (try Self.golden("postgres_exporter_escaping")))
    }

    @Test func exporterGeneratesGoldenSQLForMinimalReceipt() async throws {
        let receipt = PostgresFixtures.minimalReceipt()
        let actual = await PostgresSQLExporter().makeBlock(receipt, extracted: receipt.extracted!).sql
        #expect(actual == (try Self.golden("postgres_exporter_minimal")))
    }

    // MARK: - Escaping specifics called out explicitly (beyond the golden diff above)

    @Test func singleQuoteIsDoubledNotBackslashEscaped() {
        let sql = PostgresStore.makeInsertSQL(PostgresFixtures.fullReceipt())
        #expect(sql.contains("'Trader Joe''s #42'"))
        #expect(!sql.contains("Trader Joe\\'s"))
    }

    @Test func alreadyDoubledQuoteIsDoubledAgain() {
        // Input merchant "O''Brien's Grocery" has two raw quote-characters ('' then 's) —
        // each one gets independently doubled by `s()`, since it operates on raw characters,
        // not on already-escaped SQL. Four consecutive quotes, then the "Brien" one doubled too.
        let sql = PostgresStore.makeInsertSQL(PostgresFixtures.escapingReceipt())
        #expect(sql.contains("'O''''Brien''s Grocery'"))
    }

    @Test func backslashesPassThroughUnescaped() {
        // Postgres's default `standard_conforming_strings = on` treats backslashes in a
        // '...' literal as literal characters — they must NOT be doubled or dropped.
        let sql = PostgresStore.makeInsertSQL(PostgresFixtures.escapingReceipt())
        #expect(sql.contains("'C:\\Users\\test\\file.txt'"))
        #expect(sql.contains("'5''0\\1'"))
    }

    @Test func unicodeAndEmbeddedNewlinePassThroughUnescaped() {
        let sql = PostgresStore.makeInsertSQL(PostgresFixtures.escapingReceipt())
        #expect(sql.contains("'Café specialty ☕ \"Doorbuster\"'"))
        #expect(sql.contains("'123 Main St\nApt #4'"))
    }

    // MARK: - Null handling / decimal formatting called out explicitly

    @Test func minimalReceiptNullsEveryUnsetOptionalColumn() throws {
        let sql = PostgresStore.makeInsertSQL(PostgresFixtures.minimalReceipt())
        // Receipt-level optionals: store_number, store_address, purchased_at, tax,
        // payment_method, overall_confidence.
        #expect(sql.contains(
            "VALUES ('0BADF00D-CAFE-4000-8000-000000000003','minimal-mart_2026-01-02_r-1'," +
            "'Minimal Mart','MINIMAL MART',NULL,NULL,'2026-01-02',NULL,'R-1',5.00,NULL,NULL," +
            "TRUE,'rhea','golden_minimal_receipt.pdf',NULL)"
        ))
        // Item-level optionals, and the lineType default.
        #expect(sql.contains(
            "1,NULL,'Plain Item',NULL,NULL,NULL,'item'," +
            "NULL,NULL,NULL,NULL,NULL,NULL,NULL);"
        ))
    }

    @Test func decimalsFormatToTheirColumnsFixedPrecision() {
        // quantity: 3 decimals, unitPrice/weightLbs/pricePerLb: 4, listPrice/pricePaid: 2 —
        // even for exact whole-number inputs.
        let sql = PostgresStore.makeInsertSQL(PostgresFixtures.fullReceipt())
        #expect(sql.contains(",2.000,3.5000,NULL,NULL,7.00,7.00,0.95)"))      // qty=2, unitPrice=3.5
        #expect(sql.contains(",NULL,NULL,1.2500,2.0000,NULL,2.50,NULL)"))     // weight=1.25, perLb=2.00
    }

    // MARK: - PostgresStore / PostgresSQLExporter consistency

    @Test func storeAndExporterEscapeTheSameLiteralsForEveryField() async throws {
        // The two generators lay out whitespace differently but must never diverge on the
        // *value* they emit for a given field — that divergence is the drift this suite guards.
        for receipt in [PostgresFixtures.fullReceipt(), PostgresFixtures.escapingReceipt(), PostgresFixtures.minimalReceipt()] {
            let storeSQL = PostgresStore.makeInsertSQL(receipt)
            let exporterSQL = await PostgresSQLExporter().makeBlock(receipt, extracted: receipt.extracted!).sql

            let e = receipt.extracted!
            let expectedMerchantLiteral = "'" + e.merchant.replacingOccurrences(of: "'", with: "''") + "'"
            #expect(storeSQL.contains(expectedMerchantLiteral))
            #expect(exporterSQL.contains(expectedMerchantLiteral))

            let expectedKeyLiteral = "'" + receipt.naturalKey + "'"
            #expect(storeSQL.contains(expectedKeyLiteral))
            #expect(exporterSQL.contains(expectedKeyLiteral))

            for item in e.lineItems {
                let expectedNameLiteral = "'" + item.name.replacingOccurrences(of: "'", with: "''") + "'"
                #expect(storeSQL.contains(expectedNameLiteral))
                #expect(exporterSQL.contains(expectedNameLiteral))
            }
        }
    }
}
