import SwiftUI
import AppKit

struct ReceiptDetailView: View {
    var viewModel: ReceiptsViewModel

    var body: some View {
        Group {
            if let receipt = viewModel.selectedReceipt {
                receiptContent(receipt)
            } else {
                ContentUnavailableView {
                    Label("No Receipt Selected", systemImage: "doc.text")
                } description: {
                    Text("Select a receipt from the list to review it.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // fill detail column fully
        .navigationSplitViewColumnWidth(min: 480, ideal: 720)
    }

    @ViewBuilder
    private func receiptContent(_ receipt: Receipt) -> some View {
        if receipt.status == .failed {
            failedView(receipt)
        } else if receipt.extracted != nil {
            extractedSplitView(receipt)
        } else {
            pendingView(receipt)
        }
    }

    // MARK: - Side-by-side extracted view

    private func extractedSplitView(_ receipt: Receipt) -> some View {
        ResizableHSplit(minLeft: 190, minRight: 260) {
            pdfPanel(receipt)
        } right: {
            ReceiptEditForm(receipt: receipt, viewModel: viewModel)
                .id(receipt.id)
        }
    }

    // MARK: - PDF panel

    @ViewBuilder
    private func pdfPanel(_ receipt: Receipt) -> some View {
        VStack(spacing: 0) {
            // Header strip
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text(receipt.sourceURL.deletingPathExtension().lastPathComponent)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("PDF")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if let data = receipt.pageImage, let image = NSImage(data: data) {
                ScrollView {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
            } else {
                ContentUnavailableView {
                    Label("No Image", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("PDF image not available.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Failed

    private func failedView(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Processing Failed")
                        .font(.headline)
                    Text(receipt.sourceURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            if let msg = receipt.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Error details")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy the full error to the clipboard")
                    }
                    ScrollView {
                        Text(msg)
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .frame(maxHeight: 320)
                    .background(Color.red.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Pending (queued / inProgress)

    @ViewBuilder
    private func pendingView(_ receipt: Receipt) -> some View {
        ZStack(alignment: .bottom) {
            if let data = receipt.pageImage, let image = NSImage(data: data) {
                ScrollView {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
            } else {
                ContentUnavailableView {
                    Label("No Image", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Import a PDF receipt to preview it here.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if receipt.status == .queued, receipt.pageImage != nil {
                statusBanner {
                    Image(systemName: "clock").foregroundStyle(.secondary)
                    Text(queuedLabel(receipt))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else if receipt.status == .inProgress {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    statusBanner {
                        ProgressView().controlSize(.small)
                        Text("Extracting receipt data… \(elapsedText(receipt, now: context.date))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Floating status pill shared by the queued / in-progress states.
    @ViewBuilder
    private func statusBanner<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
            .padding(20)
    }

    private func queuedLabel(_ receipt: Receipt) -> String {
        if let p = viewModel.queuePosition(for: receipt) {
            return "Queued for processing · \(p.index)/\(p.total)"
        }
        return "Queued for processing…"
    }

    private func elapsedText(_ receipt: Receipt, now: Date) -> String {
        guard let d = viewModel.processingDuration(for: receipt, now: now) else { return "" }
        let secs = Int(d.rounded())
        return secs < 60 ? "\(secs)s" : String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
