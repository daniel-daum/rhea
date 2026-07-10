import Foundation

public enum ReceiptStatus: String, Codable, Hashable {
    case queued     = "queued"
    case inProgress = "inProgress"
    case done       = "done"
    case failed     = "failed"
}

public struct LineItem: Codable, Equatable, Hashable {
    // As printed on the receipt (abbreviated, store-specific)
    public let  name:        String
    // Model-suggested normalized name (read-only AI suggestion)
    public var  aiCommonName:   String?
    // User-assigned canonical name for cross-store comparison (e.g. "Organic Broccoli")
    public var  userCommonName: String?
    // Store department printed on receipt (PRODUCE, GROCERY, MEAT, DELI, etc.)
    public let  category:    String?
    // UPC, PLU, or SKU code
    public let  barcode:     String?

    // Quantity for unit-priced items
    public let  quantity:    Decimal?
    // Price per unit
    public let  unitPrice:   Decimal?

    // Weight in pounds for by-weight items
    public let  weightLbs:   Decimal?
    // Price per pound
    public let  pricePerLb:  Decimal?

    // Regular / shelf price for this line (before any discount)
    public let  listPrice:   Decimal?
    // Actual amount charged (after sale/coupon discount)
    public let  pricePaid:   Decimal?
    // Alias kept for backward compat; same as pricePaid when both present
    public let  lineTotal:   Decimal?

    // Model's confidence in this line item extraction (0.0–1.0); nil when unavailable
    public let  confidence:  Double?

    // Line classification: item, deposit, fee, refund, discount, non_grocery.
    // Keeps deposits/fees/refunds out of price analysis. nil is treated as "item".
    public var  lineType:    String?

    public init(
        name:           String,
        aiCommonName:   String?  = nil,
        userCommonName: String?  = nil,
        category:       String?  = nil,
        barcode:        String?  = nil,
        quantity:   Decimal? = nil,
        unitPrice:  Decimal? = nil,
        weightLbs:  Decimal? = nil,
        pricePerLb: Decimal? = nil,
        listPrice:  Decimal? = nil,
        pricePaid:  Decimal? = nil,
        lineTotal:  Decimal? = nil,
        confidence: Double?  = nil,
        lineType:   String?  = nil
    ) {
        self.name           = name
        self.aiCommonName   = aiCommonName
        self.userCommonName = userCommonName
        self.category       = category
        self.barcode    = barcode
        self.quantity   = quantity
        self.unitPrice  = unitPrice
        self.weightLbs  = weightLbs
        self.pricePerLb = pricePerLb
        self.listPrice  = listPrice
        self.pricePaid  = pricePaid
        self.lineTotal  = lineTotal
        self.confidence = confidence
        self.lineType   = lineType
    }

    enum CodingKeys: String, CodingKey {
        case name, aiCommonName, userCommonName, category, barcode
        case quantity, unitPrice, weightLbs, pricePerLb
        case listPrice, pricePaid, lineTotal, confidence, lineType
    }

    // The vision model emits "commonName"; older saved records used it too.
    private enum LegacyKeys: String, CodingKey { case commonName }

    // Lenient decoding: tolerate model quirks (numeric barcode, quoted prices, …).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = c.lenientString(.name, default: "")
        // Map model/legacy "commonName" into the AI suggestion field.
        var ai = c.lenientString(.aiCommonName)
        if ai == nil, let legacy = try? decoder.container(keyedBy: LegacyKeys.self) {
            ai = legacy.lenientString(.commonName)
        }
        self.aiCommonName   = ai
        self.userCommonName = c.lenientString(.userCommonName)
        self.category   = c.lenientString(.category)
        self.barcode    = c.lenientString(.barcode)
        self.quantity   = c.lenientDecimal(.quantity)
        self.unitPrice  = c.lenientDecimal(.unitPrice)
        self.weightLbs  = c.lenientDecimal(.weightLbs)
        self.pricePerLb = c.lenientDecimal(.pricePerLb)
        self.listPrice  = c.lenientDecimal(.listPrice)
        self.pricePaid  = c.lenientDecimal(.pricePaid)
        self.lineTotal  = c.lenientDecimal(.lineTotal)
        self.confidence = try? c.decode(Double.self, forKey: .confidence)
        self.lineType   = c.lenientString(.lineType)
    }

    // Normalized line type — defaults unknown/absent values to "item".
    public var effectiveLineType: String {
        let allowed = ["item", "deposit", "fee", "refund", "discount", "non_grocery"]
        guard let t = lineType?.lowercased(), allowed.contains(t) else { return "item" }
        return t
    }

    // Effective price paid — use pricePaid if present, fallback to lineTotal
    public var effectivePricePaid: Decimal? { pricePaid ?? lineTotal }
    // Is there a discount on this line?
    public var hasDiscount: Bool {
        guard let l = listPrice, let p = effectivePricePaid else { return false }
        return l != p
    }
}

public struct ExtractedReceipt: Codable, Equatable, Hashable {
    public let merchant:     String   // Full name as printed
    public let chain:        String?  // Brand (SAFEWAY, TRADER JOES, WHOLE FOODS, COSTCO)
    public let storeNumber:  String?
    public let storeAddress: String?
    public let date:         String   // ISO-8601
    public let receiptNumber: String?
    public let total:        Decimal
    public let tax:          Decimal?
    public let paymentMethod: String?
    public let lineItems:    [LineItem]
    // Model's overall confidence in the entire extraction (0.0–1.0); nil when unavailable
    public let overallConfidence: Double?

    public init(
        merchant:      String,
        chain:         String?  = nil,
        storeNumber:   String?  = nil,
        storeAddress:  String?  = nil,
        date:          String,
        receiptNumber: String?  = nil,
        total:         Decimal,
        tax:           Decimal? = nil,
        paymentMethod: String?  = nil,
        lineItems:     [LineItem],
        overallConfidence: Double? = nil
    ) {
        self.merchant      = merchant
        self.chain         = chain
        self.storeNumber   = storeNumber
        self.storeAddress  = storeAddress
        self.date          = date
        self.receiptNumber = receiptNumber
        self.total         = total
        self.tax           = tax
        self.paymentMethod = paymentMethod
        self.lineItems     = lineItems
        self.overallConfidence = overallConfidence
    }

    enum CodingKeys: String, CodingKey {
        case merchant, chain, storeNumber, storeAddress, date
        case receiptNumber, total, tax, paymentMethod, lineItems
        case overallConfidence
    }

    // Lenient decoding: tolerate model quirks (numeric storeNumber, quoted total, …).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.merchant      = c.lenientString(.merchant, default: "")
        self.chain         = c.lenientString(.chain)
        self.storeNumber   = c.lenientString(.storeNumber)
        self.storeAddress  = c.lenientString(.storeAddress)
        self.date          = c.lenientString(.date, default: "")
        self.receiptNumber = c.lenientString(.receiptNumber)
        self.total         = c.lenientDecimal(.total, default: 0)
        self.tax           = c.lenientDecimal(.tax)
        self.paymentMethod = c.lenientString(.paymentMethod)
        self.lineItems     = (try? c.decode([LineItem].self, forKey: .lineItems)) ?? []
        self.overallConfidence = try? c.decode(Double.self, forKey: .overallConfidence)
    }
}

public struct Receipt: Identifiable, Codable, Equatable, Hashable {
    public let id:         UUID
    public let sourceURL:  URL
    public let pageImage:  Data?
    public var status:     ReceiptStatus
    public var extracted:  ExtractedReceipt?
    public var confirmed:  Bool
    public var errorMessage: String?
    // Processing timeline — drives queue position and the count-up timer.
    public var submittedAt:  Date?
    public var startedAt:    Date?
    public var finishedAt:   Date?

    public init(
        id:           UUID = UUID(),
        sourceURL:    URL,
        pageImage:    Data?             = nil,
        status:       ReceiptStatus,
        extracted:    ExtractedReceipt? = nil,
        confirmed:    Bool              = false,
        errorMessage: String?           = nil,
        submittedAt:  Date?             = nil,
        startedAt:    Date?             = nil,
        finishedAt:   Date?             = nil
    ) {
        self.id           = id
        self.sourceURL    = sourceURL
        self.pageImage    = pageImage
        self.status       = status
        self.extracted    = extracted
        self.confirmed    = confirmed
        self.errorMessage = errorMessage
        self.submittedAt  = submittedAt
        self.startedAt    = startedAt
        self.finishedAt   = finishedAt
    }
}
