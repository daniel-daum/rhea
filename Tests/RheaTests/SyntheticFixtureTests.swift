import Testing
import Foundation
@testable import Rhea

/// Exercises the synthetic fixture library end-to-end: renders each fixture PDF,
/// serves its canned model response from an in-process stub server, and checks
/// the real ExtractionService pipeline decodes it into the matching golden receipt.
struct SyntheticFixtureTests {
    static let fixtureNames = [
        "testmart_by_weight",
        "testmart_multibuy",
        "testmart_discounts",
        "testmart_deposits_refund",
        "testmart_damaged_scan",
    ]

    private static var fixturesBundle: Bundle { Bundle(for: StubExtractionServer.self) }

    // Fixture files (PDFs, golden JSON, raw model-response text) are copied flat into the
    // test bundle's Resources dir by XcodeGen's source-globbing, regardless of their
    // subdirectory under Tests/Fixtures — filenames alone are unique across fixture kinds
    // since each kind uses a distinct extension (.pdf / .json / .txt).
    private static func url(_ name: String, ext: String) -> URL? {
        fixturesBundle.url(forResource: name, withExtension: ext)
    }

    @Test(arguments: fixtureNames)
    func fixtureIsDemonstrablySynthetic(name: String) throws {
        let goldenURL = try #require(Self.url(name, ext: "json"))
        let data = try Data(contentsOf: goldenURL)
        let receipt = try JSONDecoder().decode(ExtractedReceipt.self, from: data)

        #expect(receipt.merchant.contains("TESTMART"))
        #expect(receipt.chain == "TESTMART")
    }

    @Test(arguments: fixtureNames)
    func fixturePDFRendersToNonEmptyImage(name: String) async throws {
        let pdfURL = try #require(Self.url(name, ext: "pdf"))
        let png = await PDFService.renderFirstPage(of: pdfURL)
        let png2 = try #require(png)
        #expect(!png2.isEmpty)
    }

    @Test(arguments: fixtureNames)
    func stubServerRoundTripsExtractionService(name: String) async throws {
        let responseURL = try #require(Self.url(name, ext: "txt"))
        let responseText = try String(contentsOf: responseURL, encoding: .utf8)

        let goldenURL = try #require(Self.url(name, ext: "json"))
        let goldenData = try Data(contentsOf: goldenURL)
        let expected = try JSONDecoder().decode(ExtractedReceipt.self, from: goldenData)

        let server = try StubExtractionServer(modelResponseContent: responseText)
        try server.start()
        defer { server.stop() }

        // Image payload content doesn't matter to the stub — any bytes exercise the same code path.
        let dummyImage = Data([0x89, 0x50, 0x4E, 0x47])

        let extracted = try await ExtractionService.extract(
            imageData: dummyImage,
            endpoint: server.endpoint,
            model: "stub-model"
        )

        #expect(extracted == expected)
    }
}
