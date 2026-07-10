import SwiftUI

// MARK: - Editable line item (stable identity for ForEach binding)

private struct EditableLineItem: Identifiable {
    var id         = UUID()
    // Receipt-printed name (as-is from LLM)
    var name:       String
    // Model suggestion (read-only) + the user's own normalized name
    var aiCommonName:   String
    var userCommonName: String
    var category:   String
    var barcode:    String
    // By-unit fields
    var quantity:   String
    var unitPrice:  String
    // By-weight fields
    var weightLbs:  String
    var pricePerLb: String
    // Pricing
    var listPrice:  String
    var pricePaid:  String
    // Model confidence for this item (read-only, passed through on save)
    var confidence: Double?
    // Line classification (item/deposit/fee/refund/discount/non_grocery), passed through on save
    var lineType:   String?

    init(name: String) {
        self.name           = name
        self.aiCommonName   = ""
        self.userCommonName = ""
        self.category   = ""
        self.barcode    = ""
        self.quantity   = ""
        self.unitPrice  = ""
        self.weightLbs  = ""
        self.pricePerLb = ""
        self.listPrice  = ""
        self.pricePaid  = ""
        self.confidence = nil
        self.lineType   = nil
    }

    init(from item: LineItem) {
        self.id         = UUID()
        self.name           = item.name
        self.aiCommonName   = item.aiCommonName   ?? ""
        self.userCommonName = item.userCommonName ?? ""
        self.category   = item.category   ?? ""
        self.barcode    = item.barcode    ?? ""
        self.quantity   = item.quantity.map   { "\($0)" } ?? ""
        self.unitPrice  = item.unitPrice.map  { "\($0)" } ?? ""
        self.weightLbs  = item.weightLbs.map  { "\($0)" } ?? ""
        self.pricePerLb = item.pricePerLb.map { "\($0)" } ?? ""
        self.listPrice  = item.listPrice.map  { "\($0)" } ?? ""
        self.pricePaid  = (item.pricePaid ?? item.lineTotal).map { "\($0)" } ?? ""
        self.confidence = item.confidence
        self.lineType   = item.lineType
    }

    func toLineItem() -> LineItem {
        let paid = Decimal(string: pricePaid)
        let list = Decimal(string: listPrice)
        return LineItem(
            name:           name,
            aiCommonName:   aiCommonName.isEmpty   ? nil : aiCommonName,
            userCommonName: userCommonName.isEmpty ? nil : userCommonName,
            category:       category.isEmpty       ? nil : category,
            barcode:    barcode.isEmpty    ? nil : barcode,
            quantity:   Decimal(string: quantity),
            unitPrice:  Decimal(string: unitPrice),
            weightLbs:  Decimal(string: weightLbs),
            pricePerLb: Decimal(string: pricePerLb),
            listPrice:  list,
            pricePaid:  paid,
            lineTotal:  paid ?? Decimal(string: pricePaid),
            confidence: confidence,
            lineType:   lineType
        )
    }
}

// MARK: - ReceiptEditForm

struct ReceiptEditForm: View {
    let receipt: Receipt
    var viewModel: ReceiptsViewModel

    @State private var merchant:      String
    @State private var chain:         String
    @State private var storeNumber:   String
    @State private var storeAddress:  String
    @State private var date:          String
    @State private var receiptNumber: String
    @State private var total:         String
    @State private var tax:           String
    @State private var paymentMethod: String
    @State private var lineItems:     [EditableLineItem]

    // Read-only model fields passed through on save
    @State private var overallConfidence: Double?
    // True when the model didn't extract a receipt number — the field is auto-generated
    @State private var isReceiptNumberAuto: Bool

    // Fixed pricing-column geometry — shared by every row so edges line up exactly.
    private let qtyW:   CGFloat = 44
    private let opW:    CGFloat = 18
    private let eaW:    CGFloat = 64
    private var priceW: CGFloat { qtyW + opW + eaW }   // 126 — total/struck share this right edge

    private var isReadOnly: Bool { receipt.confirmed }

    init(receipt: Receipt, viewModel: ReceiptsViewModel) {
        self.receipt   = receipt
        self.viewModel = viewModel
        let e = receipt.extracted
        _merchant      = State(initialValue: e?.merchant      ?? "")
        _chain         = State(initialValue: e?.chain         ?? "")
        _storeNumber   = State(initialValue: e?.storeNumber   ?? "")
        _storeAddress  = State(initialValue: e?.storeAddress  ?? "")
        _date          = State(initialValue: e?.date          ?? "")
        // If the model didn't extract a receipt number, fill in the generated fallback
        let hasExtractedReceiptNumber = e?.receiptNumber != nil
        _receiptNumber = State(initialValue: e?.receiptNumber ?? receipt.generatedReceiptNumber)
        _isReceiptNumberAuto = State(initialValue: !hasExtractedReceiptNumber)
        _total         = State(initialValue: e.map { "\($0.total)" } ?? "")
        _tax           = State(initialValue: e?.tax.map { "\($0)" } ?? "")
        _paymentMethod = State(initialValue: e?.paymentMethod ?? "")
        _lineItems     = State(initialValue: e?.lineItems.map { EditableLineItem(from: $0) } ?? [])
        _overallConfidence = State(initialValue: e?.overallConfidence)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                detailsCard
                lineItemsCard
                confirmFooter
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card chrome

    @ViewBuilder
    private func card<Content: View>(_ title: String, systemImage: String,
                                     trailing: String? = nil,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                Spacer()
                if let trailing {
                    Text(trailing).font(.caption).foregroundStyle(.tertiary)
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    // MARK: - Receipt details

    private var detailsCard: some View {
        card("Receipt Details", systemImage: "doc.text") {
            VStack(spacing: 7) {
                idRow("Receipt ID", value: receipt.publicID)
                idRow("Key",        value: receipt.naturalKey)
                if let conf = overallConfidence {
                    confidenceRow(conf)
                }
                detailRow("Merchant",      $merchant)
                detailRow("Chain",         $chain)
                detailRow("Store #",       $storeNumber)
                detailRow("Store Address", $storeAddress)
                detailRow("Date",          $date)
                receiptNumberRow
                detailRow("Total",         $total)
                detailRow("Tax",           $tax)
                detailRow("Payment",       $paymentMethod)
            }
        }
    }

    private var receiptNumberRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Receipt #")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if isReceiptNumberAuto && !isReadOnly {
                    Text("auto-generated · replace with value from image")
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.85))
                }
            }
            .frame(width: 116, alignment: .leading)

            HStack(spacing: 6) {
                if isReceiptNumberAuto && !isReadOnly {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange.opacity(0.7))
                }
                TextField("", text: $receiptNumber)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(isReadOnly ? Color.secondary : (isReceiptNumberAuto ? Color.orange.opacity(0.9) : Color.primary))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .disabled(isReadOnly)
                    .onChange(of: receiptNumber) { _, newValue in
                        // Once the user types something different from the generated value, clear the auto flag
                        if newValue != receipt.generatedReceiptNumber {
                            isReceiptNumberAuto = false
                        }
                    }
            }
        }
    }

    private func confidenceRow(_ confidence: Double) -> some View {
        HStack(spacing: 12) {
            Text("AI Confidence")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 116, alignment: .leading)
            Spacer()
            confidencePill(confidence)
        }
    }

    private func detailRow(_ label: String, _ text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 116, alignment: .leading)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(isReadOnly ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .disabled(isReadOnly)
        }
    }

    private func idRow(_ label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 116, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    // MARK: - Line items

    private var lineItemsCard: some View {
        card("Line Items", systemImage: "list.bullet",
             trailing: lineItems.isEmpty ? nil : "\(lineItems.count) item\(lineItems.count == 1 ? "" : "s")") {
            if lineItems.isEmpty && isReadOnly {
                Text("No line items")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach($lineItems) { $item in
                        lineItemRow(item: $item)
                        if item.id != lineItems.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
                if !isReadOnly {
                    Button {
                        lineItems.append(EditableLineItem(name: ""))
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill").font(.callout)
                    }
                    .buttonStyle(.link)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func lineItemRow(item: Binding<EditableLineItem>) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // LEFT — identity (flexible width)
            VStack(alignment: .leading, spacing: 4) {
                // Receipt item name — primary, with confidence badge at trailing end
                HStack(spacing: 6) {
                    TextField("Item name", text: item.name)
                        .textFieldStyle(.plain)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .disabled(isReadOnly)
                    if let conf = item.wrappedValue.confidence {
                        confidencePill(conf)
                    }
                }

                // Your common name — secondary (user-confirmed data)
                HStack(spacing: 5) {
                    Image(systemName: "tag")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    TextField("Your common name", text: item.userCommonName)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .disabled(isReadOnly)
                }

                // AI suggestion — distinct accent class
                aiSuggestion(item: item)

                // Category + barcode — tertiary scaffolding, in aligned columns
                HStack(spacing: 16) {
                    categoryTag(item: item)
                        .frame(width: 116, alignment: .leading)
                    barcodeTag(item: item)
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // RIGHT — pricing math (fixed columns, shared right edge)
            pricingColumn(item: item)

            // Delete (only while editing; every editing row matches, so columns still align)
            if !isReadOnly {
                Button {
                    let id = item.wrappedValue.id
                    lineItems.removeAll { $0.id == id }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(0.8))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
    }

    // MARK: - Line-item subviews

    /// AI suggestion: a single distinct accent (blue) — outlined "AI" mark + readable text.
    @ViewBuilder
    private func aiSuggestion(item: Binding<EditableLineItem>) -> some View {
        let ai = item.wrappedValue.aiCommonName
        if !ai.isEmpty {
            HStack(spacing: 5) {
                Text("AI")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(.blue.opacity(0.55), lineWidth: 0.75)
                    )
                Text(ai)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                if !isReadOnly && item.wrappedValue.userCommonName.isEmpty {
                    Button { item.wrappedValue.userCommonName = ai } label: {
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Use this suggestion as your common name")
                }
            }
        }
    }

    /// Category — tertiary: small muted text with a low-key color dot (no heavy fill).
    private func categoryTag(item: Binding<EditableLineItem>) -> some View {
        let color = categoryColor(item.wrappedValue.category)
        return HStack(spacing: 5) {
            Circle().fill(color.opacity(0.85)).frame(width: 6, height: 6)
            TextField("category", text: item.category)
                .textFieldStyle(.plain)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .disabled(isReadOnly)
        }
    }

    /// Barcode — tertiary, its own aligned column.
    private func barcodeTag(item: Binding<EditableLineItem>) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "barcode")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
            TextField("barcode", text: item.barcode)
                .textFieldStyle(.plain)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .disabled(isReadOnly)
        }
    }

    /// Right-side pricing math: total (primary), qty × ea (fixed cols), struck original.
    private func pricingColumn(item: Binding<EditableLineItem>) -> some View {
        let v = item.wrappedValue
        let isWeight   = !v.weightLbs.isEmpty || !v.pricePerLb.isEmpty
        let discounted = !v.listPrice.isEmpty && v.listPrice != v.pricePaid
        return VStack(alignment: .trailing, spacing: 3) {
            // Line total — primary, shares the column's right edge
            TextField("", text: item.pricePaid)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .monospaced).weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: priceW, alignment: .trailing)
                .disabled(isReadOnly)

            // qty × ea  (or  wt @ /lb) — fixed sub-columns
            HStack(spacing: 0) {
                numField(isWeight ? item.weightLbs : item.quantity)
                    .frame(width: qtyW, alignment: .trailing)
                Text(isWeight ? "@" : "×")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: opW, alignment: .center)
                numField(isWeight ? item.pricePerLb : item.unitPrice)
                    .frame(width: eaW, alignment: .trailing)
            }
            .frame(width: priceW, alignment: .trailing)

            // Original price before discount — muted + struck (before/after)
            if discounted {
                Text(v.listPrice)
                    .font(.caption.monospacedDigit())
                    .strikethrough(true, color: .secondary)
                    .foregroundStyle(.tertiary)
                    .frame(width: priceW, alignment: .trailing)
            }
        }
        .frame(width: priceW, alignment: .trailing)
    }

    private func numField(_ text: Binding<String>) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .disabled(isReadOnly)
    }

    // MARK: - Confidence badge

    /// Small colored capsule showing a confidence percentage.
    private func confidencePill(_ confidence: Double) -> some View {
        let pct   = Int((confidence * 100).rounded())
        let color = confidenceColor(confidence)
        return Text("\(pct)%")
            .font(.system(size: 9, weight: .semibold).monospacedDigit())
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func confidenceColor(_ c: Double) -> Color {
        if c >= 0.85 { return .green }
        if c >= 0.60 { return .orange }
        return .red
    }

    /// Muted, low-saturation category palette — carried by a small dot, not a fill.
    private func categoryColor(_ raw: String) -> Color {
        let s = raw.uppercased()
        if s.contains("PRODUCE")                          { return .green }
        if s.contains("MEAT") || s.contains("SEAFOOD")    { return .pink }
        if s.contains("LIQUOR") || s.contains("BEER") || s.contains("WINE") { return .purple }
        if s.contains("DELI")                             { return .orange }
        if s.contains("BAK")                              { return .brown }
        if s.contains("FROZEN") || s.contains("REFRIG")   { return .teal }
        if s.contains("DAIRY")                            { return .indigo }
        if s.contains("GROC")                             { return .mint }
        return .gray
    }

    // MARK: - Confirm footer

    @ViewBuilder
    private var confirmFooter: some View {
        if receipt.confirmed {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Confirmed & Saved")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("Reviewed. Export from Settings to write to CSV or Postgres.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.08)))
        } else {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Confirm & Export")
                            .font(.body.weight(.semibold))
                        Text("Marks as reviewed. Use Export in Settings to save.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Confirm") { applyAndConfirm() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .keyboardShortcut(.return, modifiers: .command)
                }
                HStack(spacing: 5) {
                    Image(systemName: "keyboard")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("⌘↵ to confirm · set your common name for cross-store comparison · export from Settings")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    // MARK: - Confirm action

    private func applyAndConfirm() {
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespaces) }
        let updated = ExtractedReceipt(
            merchant:      trim(merchant),
            chain:         trim(chain).isEmpty        ? nil : trim(chain),
            storeNumber:   trim(storeNumber).isEmpty  ? nil : trim(storeNumber),
            storeAddress:  trim(storeAddress).isEmpty ? nil : trim(storeAddress),
            date:          trim(date),
            receiptNumber: trim(receiptNumber).isEmpty ? nil : trim(receiptNumber),
            total:         Decimal(string: trim(total))      ?? (receipt.extracted?.total ?? 0),
            tax:           trim(tax).isEmpty ? nil           : Decimal(string: trim(tax)),
            paymentMethod: trim(paymentMethod).isEmpty ? nil : trim(paymentMethod),
            lineItems:     lineItems.map { $0.toLineItem() },
            overallConfidence: overallConfidence
        )
        Task { await viewModel.updateAndConfirm(receipt.id, extracted: updated) }
    }
}
