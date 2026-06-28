import Foundation
import Observation

// MARK: - Export status

enum ExportStatus {
    case success(String)
    case failure(String)

    var message:   String  { switch self { case .success(let m): m; case .failure(let m): m } }
    var isSuccess: Bool    { if case .success = self { return true }; return false }
}

@Observable
@MainActor
class ReceiptsViewModel {
    var receipts: [Receipt]
    var sidebarSelection: SidebarItem = .receipts
    var receiptFilter:    ReceiptFilter = .all
    var selectedReceipt:  Receipt?

    // AI extraction config
    var extractionEndpoint = ExtractionService.defaultEndpoint
    var extractionModel    = ExtractionService.defaultModel

    // Postgres credentials
    var postgresConfig = PostgresConfig()

    // Export state
    var isExporting:   Bool          = false
    var exportStatus:  ExportStatus? = nil
    var csvExportURL:  URL?          = nil

    // Durable on-disk store (Application Support). Source of truth across launches.
    private let store = LocalStore()

    /// Guards the sequential queue drain so only one extraction runs at a time.
    private var isProcessing = false

    init(receipts: [Receipt] = []) {
        self.receipts        = receipts
        self.selectedReceipt = receipts.first { $0.status == .queued || $0.status == .inProgress }
    }

    /// Loads persisted receipts on launch. Only runs while in-memory state is empty
    /// so it can't clobber anything the user added before the load completed.
    func loadFromDisk() async {
        guard receipts.isEmpty else { return }
        guard let loaded = try? await store.load(), !loaded.isEmpty else { return }
        receipts = loaded.sorted {
            $0.sourceURL.lastPathComponent.localizedStandardCompare($1.sourceURL.lastPathComponent) == .orderedAscending
        }
        if selectedReceipt == nil {
            selectedReceipt = receipts.first { $0.status == .queued || $0.status == .inProgress } ?? receipts.first
        }
        // A prior crash/quit may have left items mid-flight; re-queue and resume draining.
        for i in receipts.indices where receipts[i].status == .inProgress {
            receipts[i].status    = .queued
            receipts[i].startedAt = nil
        }
        if receipts.contains(where: { $0.status == .queued }) {
            Task { await processQueue() }
        }
    }

    // MARK: - Filtered view

    var filteredReceipts: [Receipt] {
        switch receiptFilter {
        case .all:       return receipts
        case .queued:    return receipts.filter { $0.status == .queued || $0.status == .inProgress }
        case .processed: return receipts.filter { $0.status == .done && !$0.confirmed }
        case .confirmed: return receipts.filter { $0.confirmed }
        case .failed:    return receipts.filter { $0.status == .failed }
        }
    }

    func badgeCount(for item: SidebarItem) -> Int {
        switch item {
        case .receipts: return receipts.filter { $0.status == .queued || $0.status == .inProgress }.count
        case .settings: return 0
        }
    }

    // MARK: - Queue position & timing

    /// Position among currently queued + in-progress receipts (1-based) plus the total,
    /// ordered by submission time. nil when the receipt isn't pending.
    func queuePosition(for receipt: Receipt) -> (index: Int, total: Int)? {
        let pending = receipts
            .filter { $0.status == .queued || $0.status == .inProgress }
            .sorted { ($0.submittedAt ?? .distantPast) < ($1.submittedAt ?? .distantPast) }
        guard let idx = pending.firstIndex(where: { $0.id == receipt.id }) else { return nil }
        return (idx + 1, pending.count)
    }

    /// Elapsed processing time: live to `now` while in-progress, final span once done/failed.
    func processingDuration(for receipt: Receipt, now: Date = Date()) -> TimeInterval? {
        guard let start = receipt.startedAt else { return nil }
        let end = receipt.finishedAt ?? now
        return max(0, end.timeIntervalSince(start))
    }

    // MARK: - Add receipt

    /// Imports a source file: copies it into the vault, renders its first page, and queues it.
    func importReceipt(from sourceURL: URL) async {
        let id = UUID()
        // Copy the original into the vault so nothing depends on the user's file location.
        let storedURL = (try? await store.storeOriginal(sourceURL, for: id)) ?? sourceURL
        let imageData = await PDFService.renderFirstPage(of: storedURL)
        if let imageData { try? await store.storeImage(imageData, for: id) }

        addReceipt(Receipt(id: id, sourceURL: storedURL, pageImage: imageData,
                           status: .queued, submittedAt: Date()))
        // Non-blocking: drain the queue so bulk imports populate fast and process one-by-one.
        Task { await processQueue() }
    }

    func addReceipt(_ receipt: Receipt) {
        receipts.append(receipt)
        selectedReceipt = receipt
        receiptFilter   = .queued
        persist(receipt)
    }

    // MARK: - Sequential processing queue

    /// Drains queued receipts one at a time, in import order. Reentrancy-guarded so
    /// concurrent triggers (bulk import, resume, manual) collapse into a single worker.
    func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        while let next = receipts.first(where: { $0.status == .queued }) {
            await runExtraction(next.id)
        }
    }

    /// Manual trigger kept for the context menu / detail button: (re)queue then drain.
    func extractReceipt(_ receipt: Receipt) async {
        guard let current = receipts.first(where: { $0.id == receipt.id }) else { return }
        if current.status == .done || current.status == .failed {
            update(receipt.id) {
                $0.status       = .queued
                $0.extracted    = nil
                $0.errorMessage = nil
                $0.startedAt    = nil
                $0.finishedAt   = nil
                if $0.submittedAt == nil { $0.submittedAt = Date() }
            }
        }
        await processQueue()
    }

    private func runExtraction(_ id: UUID) async {
        guard let receipt = receipts.first(where: { $0.id == id }) else { return }
        guard let image = receipt.pageImage else {
            update(id) {
                $0.status       = .failed
                $0.errorMessage = "No image available to extract from."
                $0.finishedAt   = Date()
            }
            return
        }

        update(id) {
            $0.status       = .inProgress
            $0.startedAt    = Date()
            $0.finishedAt   = nil
            $0.errorMessage = nil
        }

        do {
            let extracted = try await ExtractionService.extract(
                imageData: image,
                endpoint:  extractionEndpoint,
                model:     extractionModel
            )
            update(id) {
                $0.status     = .done
                $0.extracted  = extracted
                $0.finishedAt = Date()
            }
        } catch {
            update(id) {
                $0.status       = .failed
                $0.errorMessage = error.localizedDescription
                $0.finishedAt   = Date()
            }
        }
    }

    // MARK: - Confirm (in-memory only; use Export to persist)

    func confirmReceipt(_ receipt: Receipt) {
        update(receipt.id) { $0.confirmed = true }
    }

    /// Toggles the reviewed/confirmed flag (used by the context menu).
    func setConfirmed(_ id: UUID, _ confirmed: Bool) {
        update(id) { $0.confirmed = confirmed }
    }

    func updateAndConfirm(_ id: UUID, extracted: ExtractedReceipt) async {
        update(id) {
            $0.extracted = extracted
            $0.confirmed = true
        }
    }

    // MARK: - Re-process

    /// Re-sends an already-processed (or failed) receipt to the model: re-queue + drain.
    func reprocessReceipt(_ receipt: Receipt) async {
        guard receipt.pageImage != nil else { return }
        update(receipt.id) {
            $0.confirmed    = false
            $0.extracted    = nil
            $0.errorMessage = nil
            $0.status       = .queued
            $0.submittedAt  = Date()
            $0.startedAt    = nil
            $0.finishedAt   = nil
        }
        await processQueue()
    }

    // MARK: - Delete

    /// Permanently removes a receipt and its on-disk files (image + original).
    func deleteReceipt(_ id: UUID) {
        receipts.removeAll { $0.id == id }
        if selectedReceipt?.id == id { selectedReceipt = nil }
        Task { try? await store.delete(id: id) }
    }

    // MARK: - CSV export

    func exportToCSV() async {
        isExporting  = true
        exportStatus = nil
        defer { isExporting = false }

        do {
            let url   = try CSVExporter.exportAll(receipts)
            let count = receipts.filter { $0.confirmed }.count
            csvExportURL = url
            exportStatus = .success("Exported \(count) receipt\(count == 1 ? "" : "s") → \(url.lastPathComponent)")
        } catch {
            exportStatus = .failure("CSV export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Postgres export

    func exportToPostgres() async {
        guard postgresConfig.isConfigured else {
            exportStatus = .failure("Fill in the database name and username first.")
            return
        }
        isExporting  = true
        exportStatus = nil
        defer { isExporting = false }

        do {
            let count = try await PostgresStore.insertAll(receipts, config: postgresConfig)
            exportStatus = .success("Inserted \(count) receipt\(count == 1 ? "" : "s") into \(postgresConfig.dbname).")
        } catch {
            exportStatus = .failure(error.localizedDescription)
        }
    }

    func testPostgresConnection() async {
        isExporting  = true
        exportStatus = nil
        defer { isExporting = false }

        do {
            try await PostgresStore.testConnection(config: postgresConfig)
            exportStatus = .success("Connected to \(postgresConfig.host):\(postgresConfig.port)/\(postgresConfig.dbname) ✓")
        } catch {
            exportStatus = .failure(error.localizedDescription)
        }
    }

    /// Persists all in-memory receipts. Backstop for app background / termination.
    func saveAll() {
        let snapshot = receipts
        Task { for r in snapshot { try? await store.save(r) } }
    }

    // MARK: - Private helpers

    private func persist(_ receipt: Receipt) {
        Task { try? await store.save(receipt) }
    }

    private func update(_ id: UUID, _ transform: (inout Receipt) -> Void) {
        guard let idx = receipts.firstIndex(where: { $0.id == id }) else { return }
        transform(&receipts[idx])
        let updated = receipts[idx]
        if selectedReceipt?.id == id { selectedReceipt = updated }
        persist(updated)
    }
}
