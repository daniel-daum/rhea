import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ReceiptListView: View {
    var viewModel: ReceiptsViewModel
    @State private var isDragTargeted = false
    @State private var pendingDeletion: Set<Receipt.ID> = []
    @State private var showDeleteConfirm = false

    private var idSelection: Binding<UUID?> {
        Binding<UUID?>(
            get: { viewModel.selectedReceipt?.id },
            set: { id in
                viewModel.selectedReceipt = id.flatMap { uid in
                    viewModel.receipts.first { $0.id == uid }
                }
            }
        )
    }

    private var filterBinding: Binding<ReceiptFilter> {
        Binding(get: { viewModel.receiptFilter }, set: { viewModel.receiptFilter = $0 })
    }

    var body: some View {
        let filtered = viewModel.filteredReceipts

        Group {
            if viewModel.sidebarSelection == .settings {
                SettingsView(viewModel: viewModel)
            } else {
                Table(filtered, selection: idSelection) {
                    TableColumn("Receipt") { receipt in
                        ReceiptNameCell(receipt: receipt)
                    }
                    .width(min: 200, ideal: 280)

                    TableColumn("Date") { receipt in
                        Text(dateText(for: receipt))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .width(min: 80, ideal: 110)

                    TableColumn("Total") { receipt in
                        if let total = receipt.extracted?.total {
                            Text(formatCurrency(total))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .width(min: 60, ideal: 88)

                    TableColumn("Status") { receipt in
                        StatusCell(status: receipt.status, confirmed: receipt.confirmed,
                                   position: viewModel.queuePosition(for: receipt))
                    }
                    .width(min: 96, ideal: 132)

                    TableColumn("Time") { receipt in
                        TimeCell(receipt: receipt, viewModel: viewModel)
                    }
                    .width(min: 50, ideal: 70)
                }
                .contextMenu(forSelectionType: Receipt.ID.self) { ids in
                    contextMenuItems(for: ids)
                }
                .alternatingRowBackgrounds(.enabled)
                .navigationTitle("Receipts")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Picker("Filter", selection: filterBinding) {
                            ForEach(ReceiptFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()

                        Button(action: importPDFs) {
                            Label("Import PDF", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("o", modifiers: .command)
                        .help("Import PDF receipts (⌘O)")
                    }
                }
                .overlay {
                    if isDragTargeted {
                        dropTargetOverlay
                    } else if filtered.isEmpty {
                        emptyStateView
                    }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
                    guard !pdfs.isEmpty else { return false }
                    Task { @MainActor in
                        for url in pdfs { await viewModel.importReceipt(from: url) }
                    }
                    return true
                } isTargeted: { isDragTargeted = $0 }
                .confirmationDialog(
                    deletePrompt,
                    isPresented: $showDeleteConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        pendingDeletion.forEach { viewModel.deleteReceipt($0) }
                        pendingDeletion.removeAll()
                    }
                    Button("Cancel", role: .cancel) { pendingDeletion.removeAll() }
                } message: {
                    Text("This permanently deletes the receipt and its stored files (image + original). This can't be undone.")
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 420, ideal: 580)
    }

    // MARK: - Context menu

    private var deletePrompt: String {
        pendingDeletion.count == 1 ? "Delete this receipt?" : "Delete \(pendingDeletion.count) receipts?"
    }

    @ViewBuilder
    private func contextMenuItems(for ids: Set<Receipt.ID>) -> some View {
        let selected = viewModel.receipts.filter { ids.contains($0.id) }
        if selected.count == 1, let r = selected.first {
            switch r.status {
            case .queued:
                Button { Task { await viewModel.extractReceipt(r) } } label: {
                    Label("Extract with AI", systemImage: "sparkles")
                }
            case .done, .failed:
                Button { Task { await viewModel.reprocessReceipt(r) } } label: {
                    Label("Re-process", systemImage: "arrow.clockwise")
                }
            case .inProgress:
                EmptyView()
            }

            if r.status == .done {
                Button { viewModel.setConfirmed(r.id, !r.confirmed) } label: {
                    Label(r.confirmed ? "Unconfirm" : "Confirm",
                          systemImage: r.confirmed ? "arrow.uturn.backward.circle" : "checkmark.circle")
                }
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([r.sourceURL])
            } label: {
                Label("Reveal Source in Finder", systemImage: "folder")
            }

            Divider()
        }

        if !selected.isEmpty {
            Button(role: .destructive) {
                pendingDeletion = ids
                showDeleteConfirm = true
            } label: {
                Label(selected.count > 1 ? "Delete \(selected.count) Receipts" : "Delete",
                      systemImage: "trash")
            }
        }
    }

    // MARK: - Import

    private func importPDFs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes     = [UTType.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories    = false
        panel.prompt = "Import"
        panel.title  = "Import Receipts"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { @MainActor in
            for url in urls { await viewModel.importReceipt(from: url) }
        }
    }

    // MARK: - Overlays

    private var dropTargetOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.06)
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .padding(10)
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.accentColor)
                Text("Drop PDFs to Import")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        switch viewModel.receiptFilter {
        case .all, .queued:
            ContentUnavailableView {
                Label("No Receipts", systemImage: "doc.badge.plus")
            } description: {
                Text("Drag PDFs here or press ⌘O to import.")
            } actions: {
                Button("Import PDF") { importPDFs() }
                    .buttonStyle(.bordered)
            }
        case .processed:
            ContentUnavailableView {
                Label("Nothing Processed", systemImage: "tray")
            } description: {
                Text("Extracted receipts awaiting your review appear here.")
            }
        case .confirmed:
            ContentUnavailableView {
                Label("Nothing Confirmed", systemImage: "checkmark.circle")
            } description: {
                Text("Receipts you confirm will appear here.")
            }
        case .failed:
            ContentUnavailableView {
                Label("No Failures", systemImage: "checkmark.seal")
            } description: {
                Text("Receipts that couldn't be processed appear here.")
            }
        }
    }

    // MARK: - Formatters

    private func dateText(for receipt: Receipt) -> String {
        guard let iso = receipt.extracted?.date else { return "—" }
        let fmt = ISO8601DateFormatter()
        guard let date = fmt.date(from: iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.locale = .current
        return fmt.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}

// MARK: - ReceiptNameCell

struct ReceiptNameCell: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: 11) {
            thumbnailView
                .frame(width: 38, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(merchantName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(receipt.sourceURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let data = receipt.pageImage, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .overlay(
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.tertiary)
                )
        }
    }

    private var merchantName: String {
        receipt.extracted?.merchant
            ?? receipt.sourceURL.deletingPathExtension().lastPathComponent
    }
}

// MARK: - StatusCell

struct StatusCell: View {
    let status: ReceiptStatus
    var confirmed: Bool = false
    var position: (index: Int, total: Int)? = nil

    var body: some View {
        HStack(spacing: 5) {
            if status == .inProgress {
                ProgressView().controlSize(.small)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.6), radius: 2.5, x: 0, y: 0)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
            if let p = position {
                Text("\(p.index)/\(p.total)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var label: String {
        switch status {
        case .queued:     return "Queued"
        case .inProgress: return "Processing"
        case .done:       return confirmed ? "Confirmed" : "Processed"
        case .failed:     return "Failed"
        }
    }

    private var color: Color {
        switch status {
        case .done:       return confirmed ? .green : .blue
        case .failed:     return .red
        case .inProgress: return .orange
        case .queued:     return .secondary
        }
    }
}

// MARK: - TimeCell (counts up while processing, final duration once done/failed)

struct TimeCell: View {
    let receipt: Receipt
    var viewModel: ReceiptsViewModel

    var body: some View {
        Group {
            if receipt.status == .inProgress {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(format(viewModel.processingDuration(for: receipt, now: context.date)))
                        .foregroundStyle(.orange)
                }
            } else if let d = viewModel.processingDuration(for: receipt) {
                Text(format(d)).foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
        .font(.subheadline.monospacedDigit())
    }

    private func format(_ t: TimeInterval?) -> String {
        guard let t else { return "—" }
        let secs = Int(t.rounded())
        if secs < 60 { return "\(secs)s" }
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
