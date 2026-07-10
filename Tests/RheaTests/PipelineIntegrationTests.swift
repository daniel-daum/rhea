import Testing
import Foundation
@testable import Rhea

/// Full-pipeline test: import a synthetic receipt PDF into a temp-vault `ReceiptsViewModel`,
/// let the sequential queue drain it against the in-process `StubExtractionServer` (golden
/// model response), edit a line item, confirm, then diff the generated Postgres SQL against a
/// checked-in golden file. No live network and no `psql` binary — extraction is served
/// in-process, and `PostgresSQLExporter.makeBlock` only builds a SQL string, it never shells out.
///
/// Regenerating a golden `.sql` file after an intentional formatting change: same recipe as
/// `PostgresSQLGoldenTests` — temporarily `print(actual)`, paste the printed value into the
/// corresponding file under `Tests/Fixtures/Golden/`, then re-run to confirm.
@MainActor
struct PipelineIntegrationTests {

    /// One fixture category per acceptance criterion (by-weight, multi-buy, discount, refund),
    /// each pinned to a fixed UUID so the generated SQL is byte-for-byte reproducible.
    static let categories: [(fixture: String, id: UUID)] = [
        ("testmart_by_weight",       UUID(uuidString: "0BADF00D-CAFE-4000-9000-0000000000A1")!),
        ("testmart_multibuy",        UUID(uuidString: "0BADF00D-CAFE-4000-9000-0000000000A2")!),
        ("testmart_discounts",       UUID(uuidString: "0BADF00D-CAFE-4000-9000-0000000000A3")!),
        ("testmart_deposits_refund", UUID(uuidString: "0BADF00D-CAFE-4000-9000-0000000000A4")!),
    ]

    private static var fixturesBundle: Bundle { Bundle(for: StubExtractionServer.self) }

    private static func url(_ name: String, ext: String) -> URL? {
        fixturesBundle.url(forResource: name, withExtension: ext)
    }

    private func tempStore() -> LocalStore {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "RheaPipelineTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return LocalStore(rootURL: dir)
    }

    private static func golden(_ name: String) throws -> String {
        let url = try #require(fixturesBundle.url(forResource: name, withExtension: "sql"))
        return try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .newlines)
    }

    /// Marks the review pass on the first line item: the user overrides the AI-suggested
    /// common name before confirming, exercising the editable field that flows into the
    /// `common_name` export column.
    private func reviewed(_ extracted: ExtractedReceipt) -> ExtractedReceipt {
        var items = extracted.lineItems
        var first = items[0]
        first.userCommonName = "user reviewed name"
        items[0] = first
        return ExtractedReceipt(
            merchant: extracted.merchant,
            chain: extracted.chain,
            storeNumber: extracted.storeNumber,
            storeAddress: extracted.storeAddress,
            date: extracted.date,
            receiptNumber: extracted.receiptNumber,
            total: extracted.total,
            tax: extracted.tax,
            paymentMethod: extracted.paymentMethod,
            lineItems: items,
            overallConfidence: extracted.overallConfidence
        )
    }

    @Test(arguments: Self.categories)
    func fullPipelineImportExtractConfirmExportSQL(category: (fixture: String, id: UUID)) async throws {
        let pdfURL = try #require(Self.url(category.fixture, ext: "pdf"))
        let responseURL = try #require(Self.url(category.fixture, ext: "txt"))
        let responseText = try String(contentsOf: responseURL, encoding: .utf8)
        let goldenURL = try #require(Self.url(category.fixture, ext: "json"))
        let goldenExtracted = try JSONDecoder().decode(ExtractedReceipt.self, from: Data(contentsOf: goldenURL))

        let server = try StubExtractionServer(modelResponseContent: responseText)
        try server.start()
        defer { server.stop() }

        let vm = ReceiptsViewModel(store: tempStore())
        vm.extractionEndpoint = server.endpoint
        vm.extractionModel    = "stub-model"

        // Import: render the real synthetic PDF (as the app would from a drag-and-drop / ⌘O
        // import), queue it, then drive the sequential queue to completion against the stub.
        let pageImage = try #require(await PDFService.renderFirstPage(of: pdfURL))
        vm.addReceipt(Receipt(
            id: category.id,
            sourceURL: pdfURL,
            pageImage: pageImage,
            status: .queued,
            submittedAt: Date()
        ))
        await vm.processQueue()

        let extracted = try #require(vm.receipts.first { $0.id == category.id })
        #expect(extracted.status == .done)
        #expect(extracted.extracted == goldenExtracted)
        #expect(!extracted.confirmed)

        // Edit a line item, then confirm — the same call `ReceiptEditForm`'s Confirm button makes.
        let edited = reviewed(try #require(extracted.extracted))
        await vm.updateAndConfirm(category.id, extracted: edited)

        let confirmed = try #require(vm.receipts.first { $0.id == category.id })
        #expect(confirmed.confirmed)
        #expect(confirmed.extracted?.lineItems.first?.userCommonName == "user reviewed name")

        // Export: assert the generated SQL matches a checked-in golden file. No live Postgres —
        // `makeBlock` only builds the SQL string, it never shells out to `psql`.
        let actualSQL = await PostgresSQLExporter().makeBlock(confirmed, extracted: edited).sql
        let goldenSQL = try Self.golden("pipeline_\(category.fixture)")
        #expect(actualSQL == goldenSQL)
    }
}
