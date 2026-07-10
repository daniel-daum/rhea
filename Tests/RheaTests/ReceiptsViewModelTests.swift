import Testing
import Foundation
@testable import Rhea

/// Exercises `ReceiptsViewModel`'s mutation hub: the sequential queue drain, crash-recovery
/// requeue on launch, and filter/badge counts. Always backed by a temp-directory `LocalStore`
/// and the in-process `StubExtractionServer`, never the real vault or a network model.
@MainActor
struct ReceiptsViewModelTests {
    private func tempStore() -> LocalStore {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "RheaViewModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        return LocalStore(rootURL: dir)
    }

    private func makeReceipt(status: ReceiptStatus, submittedAt: Date, startedAt: Date? = nil) -> Receipt {
        Receipt(
            sourceURL: URL(fileURLWithPath: "/tmp/synthetic-\(UUID().uuidString).pdf"),
            pageImage: Data([0x89, 0x50, 0x4E, 0x47]),
            status: status,
            submittedAt: submittedAt,
            startedAt: startedAt
        )
    }

    // MARK: - Sequential processing queue

    @Test func concurrentDrainTriggersCollapseIntoOneWorkerPreservingOrderAndFinalStatuses() async throws {
        let server = try StubExtractionServer(modelResponseContent: """
        {"merchant":"TESTMART","date":"2026-01-01","total":9.99,"lineItems":[]}
        """)
        try server.start()
        defer { server.stop() }

        let vm = ReceiptsViewModel(store: tempStore())
        vm.extractionEndpoint = server.endpoint
        vm.extractionModel    = "stub-model"

        let base = Date()
        let r1 = makeReceipt(status: .queued, submittedAt: base)
        let r2 = makeReceipt(status: .queued, submittedAt: base.addingTimeInterval(1))
        let r3 = makeReceipt(status: .queued, submittedAt: base.addingTimeInterval(2))
        vm.addReceipt(r1)
        vm.addReceipt(r2)
        vm.addReceipt(r3)

        // Simulate several concurrent triggers (bulk import, resume, manual) that must
        // collapse into a single drain rather than racing the queue.
        async let d1: Void = vm.processQueue()
        async let d2: Void = vm.processQueue()
        async let d3: Void = vm.processQueue()
        _ = await (d1, d2, d3)

        #expect(vm.receipts.allSatisfy { $0.status == .done })
        #expect(vm.receipts.allSatisfy { $0.extracted != nil })

        // Import order is preserved: each receipt started processing before the next.
        let byID = Dictionary(uniqueKeysWithValues: vm.receipts.map { ($0.id, $0) })
        let s1 = try #require(byID[r1.id]?.startedAt)
        let s2 = try #require(byID[r2.id]?.startedAt)
        let s3 = try #require(byID[r3.id]?.startedAt)
        #expect(s1 < s2)
        #expect(s2 < s3)
    }

    @Test func failedExtractionMarksReceiptFailedWithoutStallingTheQueue() async throws {
        let server = try StubExtractionServer(modelResponseContent: "internal error", statusCode: 500)
        try server.start()
        defer { server.stop() }

        let vm = ReceiptsViewModel(store: tempStore())
        vm.extractionEndpoint = server.endpoint
        vm.extractionModel    = "stub-model"

        let base = Date()
        let failing = makeReceipt(status: .queued, submittedAt: base)
        let ok = makeReceipt(status: .queued, submittedAt: base.addingTimeInterval(1))
        vm.addReceipt(failing)
        vm.addReceipt(ok)

        // Both hit the same failing stub; both should end up failed, not stuck queued/inProgress.
        await vm.processQueue()

        #expect(vm.receipts.allSatisfy { $0.status == .failed })
        #expect(vm.receipts.allSatisfy { $0.errorMessage != nil })
    }

    // MARK: - Crash recovery

    @Test func loadFromDiskRequeuesReceiptsStuckInProgressFromAPriorCrash() async throws {
        let store = tempStore()
        let stuck = makeReceipt(status: .inProgress, submittedAt: Date(), startedAt: Date())
        try await store.save(stuck)

        let vm = ReceiptsViewModel(store: store)
        await vm.loadFromDisk()

        // No further `await` before this check: the requeue loop runs synchronously inside
        // loadFromDisk before the background drain Task gets a chance to run, so this is
        // deterministic rather than racing the spawned `processQueue()`.
        let reloaded = try #require(vm.receipts.first { $0.id == stuck.id })
        #expect(reloaded.status == .queued)
        #expect(reloaded.startedAt == nil)
    }

    @Test func loadFromDiskLeavesDoneAndFailedReceiptsUntouched() async throws {
        let store = tempStore()
        let done = makeReceipt(status: .done, submittedAt: Date())
        let failed = makeReceipt(status: .failed, submittedAt: Date())
        try await store.save(done)
        try await store.save(failed)

        let vm = ReceiptsViewModel(store: store)
        await vm.loadFromDisk()

        #expect(vm.receipts.first { $0.id == done.id }?.status == .done)
        #expect(vm.receipts.first { $0.id == failed.id }?.status == .failed)
    }

    // MARK: - Filter counts & sidebar badge

    @Test func filteredReceiptsAndBadgeCountReflectEachStatusBucket() {
        let vm = ReceiptsViewModel(store: tempStore())
        let now = Date()
        let queued      = makeReceipt(status: .queued, submittedAt: now)
        let inProgress  = makeReceipt(status: .inProgress, submittedAt: now)
        let processed   = makeReceipt(status: .done, submittedAt: now)
        var confirmed   = makeReceipt(status: .done, submittedAt: now)
        confirmed.confirmed = true
        let failed      = makeReceipt(status: .failed, submittedAt: now)

        vm.addReceipt(queued)
        vm.addReceipt(inProgress)
        vm.addReceipt(processed)
        vm.addReceipt(confirmed)
        vm.addReceipt(failed)

        vm.receiptFilter = .all
        #expect(vm.filteredReceipts.count == 5)

        vm.receiptFilter = .queued
        #expect(Set(vm.filteredReceipts.map(\.id)) == [queued.id, inProgress.id])

        vm.receiptFilter = .processed
        #expect(vm.filteredReceipts.map(\.id) == [processed.id])

        vm.receiptFilter = .confirmed
        #expect(vm.filteredReceipts.map(\.id) == [confirmed.id])

        vm.receiptFilter = .failed
        #expect(vm.filteredReceipts.map(\.id) == [failed.id])

        #expect(vm.badgeCount(for: .receipts) == 2)
        #expect(vm.badgeCount(for: .settings) == 0)
    }
}
