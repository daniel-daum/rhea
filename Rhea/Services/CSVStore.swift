import Foundation

/// Writes confirmed receipts to a CSV file in ~/Documents/Rhea/receipts.csv.
/// One row per receipt; line items are serialised as a JSON string in a quoted column.
actor CSVStore: PersistenceStore {

    // nonisolated so the ViewModel can read it synchronously for display
    nonisolated let fileURL: URL
    nonisolated let storeDescription: String

    init() {
        let dir = URL.documentsDirectory
            .appending(path: "Rhea", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "receipts.csv")
        self.fileURL         = url
        self.storeDescription = url.path(percentEncoded: false)
    }

    // MARK: PersistenceStore

    func save(_ receipt: Receipt) async throws {
        guard receipt.extracted != nil else { return }
        var rows = try readRows()
        let newRow = makeRow(receipt)
        if let idx = rows.firstIndex(where: { $0.id == receipt.id.uuidString }) {
            rows[idx] = newRow
        } else {
            rows.append(newRow)
        }
        try writeRows(rows)
    }

    func load() async throws -> [Receipt] {
        // CSV is an export format; authoritative state lives in-memory / Postgres (Phase 5).
        []
    }

    func delete(id: UUID) async throws {
        var rows = try readRows()
        rows.removeAll { $0.id == id.uuidString }
        try writeRows(rows)
    }

    // MARK: - Private row model

    private struct Row {
        let id: String
        let csv: String
    }

    // MARK: - Read

    private func readRows() throws -> [Row] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        // Lines after the header, non-empty
        return content
            .components(separatedBy: "\n")
            .dropFirst()
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                // UUID is always the first field and never contains commas
                let id = String(line.prefix(while: { $0 != "," }))
                return Row(id: id, csv: line)
            }
    }

    // MARK: - Write

    private func writeRows(_ rows: [Row]) throws {
        let lines = ([header] + rows.map(\.csv)).joined(separator: "\n")
        try Data(lines.utf8).write(to: fileURL, options: .atomic)
    }

    private let header = "id,merchant,date,total,tax,paymentMethod,lineItems,confirmed,status,sourceFile"

    private func makeRow(_ r: Receipt) -> Row {
        let e = r.extracted! // guard in save() ensures this is non-nil
        let lineItemsJSON: String = {
            guard let data = try? JSONEncoder().encode(e.lineItems),
                  let s = String(data: data, encoding: .utf8) else { return "[]" }
            return s
        }()
        let fields: [String] = [
            r.id.uuidString,
            q(e.merchant),
            q(e.date),
            "\(e.total)",
            e.tax.map { "\($0)" } ?? "",
            q(e.paymentMethod ?? ""),
            q(lineItemsJSON),
            r.confirmed ? "true" : "false",
            r.status.rawValue,
            q(r.sourceURL.lastPathComponent),
        ]
        return Row(id: r.id.uuidString, csv: fields.joined(separator: ","))
    }

    /// RFC 4180 quoting: wrap in quotes if the field contains commas, quotes, or newlines.
    private func q(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") else {
            return s
        }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
