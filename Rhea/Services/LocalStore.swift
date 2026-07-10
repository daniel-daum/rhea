import Foundation

/// Durable on-disk store for receipts. Survives app quit / crash so nothing is lost
/// before the user exports to CSV/Postgres.
///
/// Layout under `~/Library/Application Support/Rhea/`:
///   Store/<uuid>.json            — receipt record (metadata + extracted data, no image bytes)
///   Files/<uuid>/<originalName>  — copy of the imported source file (e.g. the PDF)
///   Files/<uuid>/page.png        — rendered page image used by the UI and the model
///
/// Image bytes are kept out of the JSON (stored as a sibling PNG) so records stay small
/// and metadata-only saves (confirm, edit) don't rewrite the image.
actor LocalStore: PersistenceStore {

    nonisolated let rootURL: URL
    nonisolated let storeDescription: String

    init() {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL.applicationSupportDirectory

        self.init(rootURL: base.appending(path: "Rhea", directoryHint: .isDirectory))
    }

    /// Test seam: points the vault at an arbitrary directory (e.g. a temp dir) instead of
    /// the real Application Support location.
    init(rootURL: URL) {
        self.rootURL          = rootURL
        self.storeDescription = rootURL.path(percentEncoded: false)

        // Best-effort directory creation; individual writes also ensure their parent exists.
        try? FileManager.default.createDirectory(at: rootURL.appending(path: "Store"), withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: rootURL.appending(path: "Files"), withIntermediateDirectories: true)
    }

    // MARK: - On-disk locations

    private var recordsDir: URL { rootURL.appending(path: "Store",  directoryHint: .isDirectory) }
    private var filesDir:   URL { rootURL.appending(path: "Files",  directoryHint: .isDirectory) }

    private func recordURL(_ id: UUID) -> URL {
        recordsDir.appending(path: "\(id.uuidString).json")
    }
    private func fileDir(_ id: UUID) -> URL {
        filesDir.appending(path: id.uuidString, directoryHint: .isDirectory)
    }
    private func imageURL(_ id: UUID) -> URL {
        fileDir(id).appending(path: "page.png")
    }

    // MARK: - Blob storage

    /// Copies the imported source file into the vault and returns the new in-vault URL.
    /// No-ops if the file already lives in the vault.
    func storeOriginal(_ source: URL, for id: UUID) throws -> URL {
        let dir  = fileDir(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appending(path: source.lastPathComponent)

        if dest.standardizedFileURL == source.standardizedFileURL { return dest }
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }

    /// Writes the rendered page image alongside the original.
    func storeImage(_ data: Data, for id: UUID) throws {
        let dir = fileDir(id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: imageURL(id), options: .atomic)
    }

    // MARK: - PersistenceStore

    func save(_ receipt: Receipt) async throws {
        try FileManager.default.createDirectory(at: recordsDir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(StoredReceipt(receipt))
        try data.write(to: recordURL(receipt.id), options: .atomic)
    }

    func load() async throws -> [Receipt] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: recordsDir, includingPropertiesForKeys: nil
        ) else { return [] }

        let decoder = JSONDecoder()
        var result: [Receipt] = []
        for url in entries where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let dto  = try? decoder.decode(StoredReceipt.self, from: data)
            else { continue }
            let image = try? Data(contentsOf: imageURL(dto.id))
            result.append(dto.toReceipt(pageImage: image))
        }
        return result
    }

    func delete(id: UUID) async throws {
        let fm = FileManager.default
        try? fm.removeItem(at: recordURL(id))
        try? fm.removeItem(at: fileDir(id))
    }

    // MARK: - Codable record (image bytes intentionally excluded)

    private struct StoredReceipt: Codable {
        let id:           UUID
        let sourceURL:    URL
        let status:       ReceiptStatus
        let extracted:    ExtractedReceipt?
        let confirmed:    Bool
        let errorMessage: String?
        // Optional — older records without these keys decode as nil.
        var submittedAt:  Date?
        var startedAt:    Date?
        var finishedAt:   Date?

        init(_ r: Receipt) {
            self.id           = r.id
            self.sourceURL    = r.sourceURL
            self.status       = r.status
            self.extracted    = r.extracted
            self.confirmed    = r.confirmed
            self.errorMessage = r.errorMessage
            self.submittedAt  = r.submittedAt
            self.startedAt    = r.startedAt
            self.finishedAt   = r.finishedAt
        }

        func toReceipt(pageImage: Data?) -> Receipt {
            Receipt(
                id:           id,
                sourceURL:    sourceURL,
                pageImage:    pageImage,
                status:       status,
                extracted:    extracted,
                confirmed:    confirmed,
                errorMessage: errorMessage,
                submittedAt:  submittedAt,
                startedAt:    startedAt,
                finishedAt:   finishedAt
            )
        }
    }
}
