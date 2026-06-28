import Foundation

/// Abstract persistence interface. Phase 5 will add a PostgresStore conformance.
protocol PersistenceStore: Sendable {
    /// Upsert a receipt (insert or replace by id). Only receipts with extracted data are meaningful to persist.
    func save(_ receipt: Receipt) async throws

    /// Load all previously persisted receipts (used on app launch).
    func load() async throws -> [Receipt]

    /// Remove a receipt from the store.
    func delete(id: UUID) async throws

    /// Human-readable description of where data lives (file path, connection string, etc.).
    var storeDescription: String { get }
}

/// Default no-op implementations for stores that don't support all operations yet.
extension PersistenceStore {
    func load() async throws -> [Receipt] { [] }
    func delete(id: UUID) async throws {}
}
