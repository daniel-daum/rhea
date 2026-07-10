import Testing
import Foundation
@testable import Rhea

/// Exercises `LocalStore`'s durability contract against a temp-directory-backed vault
/// (never the real `~/Library/Application Support/Rhea`).
struct LocalStoreTests {
    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "RheaLocalStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func saveThenLoadRoundTripsReceiptAndImage() async throws {
        let store = LocalStore(rootURL: tempRoot())
        let id = UUID()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        try await store.storeImage(imageData, for: id)

        let receipt = Receipt(
            id: id,
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic.pdf"),
            status: .done,
            extracted: ExtractedReceipt(merchant: "TESTMART", date: "2026-01-01", total: Decimal(9.99), lineItems: []),
            confirmed: true
        )
        try await store.save(receipt)

        let loaded = try await store.load()
        let match = try #require(loaded.first { $0.id == id })
        #expect(match.sourceURL == receipt.sourceURL)
        #expect(match.status == receipt.status)
        #expect(match.extracted == receipt.extracted)
        #expect(match.confirmed == true)
        #expect(match.pageImage == imageData)
    }

    @Test func loadSkipsCorruptJSONRecordWithoutFailing() async throws {
        let root = tempRoot()
        let store = LocalStore(rootURL: root)

        let good = Receipt(sourceURL: URL(fileURLWithPath: "/tmp/good.pdf"), status: .queued)
        try await store.save(good)

        // Simulate a partially-written / corrupted record sitting alongside a good one.
        let corruptURL = root.appending(path: "Store", directoryHint: .isDirectory)
            .appending(path: "\(UUID().uuidString).json")
        try Data("not valid json {".utf8).write(to: corruptURL)

        let loaded = try await store.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.id == good.id)
    }

    @Test func deleteRemovesRecordAndAssociatedFiles() async throws {
        let store = LocalStore(rootURL: tempRoot())
        let id = UUID()
        try await store.storeImage(Data([0x1, 0x2]), for: id)
        try await store.save(Receipt(id: id, sourceURL: URL(fileURLWithPath: "/tmp/x.pdf"), status: .queued))

        #expect(try await store.load().count == 1)

        try await store.delete(id: id)

        #expect(try await store.load().isEmpty)
    }
}
