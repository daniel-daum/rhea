import Foundation

// MARK: - Errors

enum ExtractionError: LocalizedError {
    case noImage
    case badEndpoint(String)
    case httpError(Int, String)
    case emptyResponse
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noImage:                  return "Receipt has no image data to extract from."
        case .badEndpoint(let u):       return "Invalid endpoint URL: \(u)"
        case .httpError(let c, let b):  return "HTTP \(c) from extraction server.\n\(b)"
        case .emptyResponse:            return "Extraction server returned an empty response."
        case .parseError(let d):        return "Could not parse extraction JSON: \(d)"
        }
    }
}

// MARK: - Service

enum ExtractionService {
    // Use 127.0.0.1 explicitly — 'localhost' can resolve to ::1 (IPv6) on macOS,
    // causing connection refused when LM Studio listens on the IPv4 loopback.
    static let defaultEndpoint = "http://127.0.0.1:1234/v1/chat/completions"
    // Set this to the model identifier shown in LM Studio's "Chat" tab
    static let defaultModel    = "local-model"

    static func extract(imageData: Data, endpoint: String, model: String) async throws -> ExtractedReceipt {
        guard let url = URL(string: endpoint) else {
            throw ExtractionError.badEndpoint(endpoint)
        }

        let base64  = imageData.base64EncodedString()
        let dataURI = "data:image/png;base64,\(base64)"

        let body = ChatRequest(
            model: model,
            messages: [
                ChatRequest.Message(role: "system", content: [
                    .text("You are a grocery receipt OCR specialist. Extract structured data from receipt images into JSON exactly as instructed."),
                ]),
                ChatRequest.Message(role: "user", content: [
                    .text(prompt),
                    .imageURL(dataURI: dataURI),
                ]),
            ],
            // Server accepts only "json_schema" or "text"; "text" + the JSON-only prompt
            // and extractJSON() parsing is the most broadly compatible choice.
            responseFormat: .init(type: "text"),
            temperature: 0.05,
            maxTokens: 3000
        )

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody       = try JSONEncoder().encode(body)
        req.timeoutInterval = 240   // 32B model can take a while on first inference

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw ExtractionError.httpError(http.statusCode, msg)
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }

        let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let raw = chat.choices.first?.message.content, !raw.isEmpty else {
            throw ExtractionError.emptyResponse
        }

        guard let jsonData = extractJSON(from: raw) else {
            throw ExtractionError.parseError("Could not locate JSON in model response.")
        }

        do {
            return try JSONDecoder().decode(ExtractedReceipt.self, from: jsonData)
        } catch {
            let snippet = String(data: jsonData.prefix(300), encoding: .utf8) ?? ""
            throw ExtractionError.parseError("\(error.localizedDescription)\n\nResponse snippet:\n\(snippet)")
        }
    }

    // Strip optional markdown code fences (```json ... ```) that some models add
    private static func extractJSON(from raw: String) -> Data? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if s.hasPrefix("```") {
            // Drop first line (```json or ```)
            if let nl = s.range(of: "\n") { s = String(s[nl.upperBound...]) }
            // Drop trailing ```
            if s.hasSuffix("```") { s = String(s.dropLast(3)) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find outermost { ... } in case of leading prose
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            s = String(s[start...end])
        }

        return s.data(using: .utf8)
    }

    // MARK: - Prompt

    private static let prompt = """
    Extract ALL data from this grocery receipt image and return a single JSON object. \
    Use exactly this structure:

    {
      "merchant": "Store name as printed",
      "chain": "Brand only (e.g. SAFEWAY, TRADER JOES, WHOLE FOODS, COSTCO, GROCERY OUTLET, PIEDMONT GROCERY)",
      "storeNumber": "Store/location number if visible, else null",
      "storeAddress": "Store street address if visible, else null",
      "date": "2024-01-15T00:00:00Z",
      "receiptNumber": "Transaction or receipt number if visible, else null",
      "total": 42.50,
      "tax": 3.50,
      "paymentMethod": "Visa ****1234",
      "overallConfidence": 0.95,
      "lineItems": [
        {
          "name": "Item name EXACTLY as printed on receipt",
          "commonName": "Short consumer-friendly name for cross-store comparison",
          "category": "Department as printed (PRODUCE, GROCERY, MEAT, DELI, REFRIG/FROZEN, BAKED GOODS, LIQUOR, GROC NONEDIBLE, etc.)",
          "barcode": "UPC or PLU code if shown, else null",
          "lineType": "item",
          "quantity": 2,
          "unitPrice": 2.49,
          "weightLbs": null,
          "pricePerLb": null,
          "listPrice": 5.98,
          "pricePaid": 4.98,
          "lineTotal": 4.98,
          "confidence": 0.97
        }
      ]
    }

    RULES — follow exactly:
    - date: ISO-8601 format YYYY-MM-DDTHH:MM:SSZ; use T00:00:00Z when time is not shown
    - All price/quantity values are JSON numbers, NEVER strings
    - commonName: concise, store-neutral, LOWERCASE name a shopper would use to compare across \
    stores, 1-4 words, plural where natural, no brand unless the brand IS the product \
    (e.g. "organic broccoli" not "SIG FARMS BROCCOLI"; "kona coffee" not "SIG COFFEE KONA BL"). \
    Keep qualifiers that change the price: organic, nonfat/whole, boneless. Drop sizes and \
    marketing words.
    - For BY-UNIT items: set quantity + unitPrice; set weightLbs and pricePerLb to null
    - For BY-WEIGHT items: set weightLbs + pricePerLb; set quantity and unitPrice to null. \
    LOOK CAREFULLY for weight lines — e.g. "2.44 lb @ $0.99/lb", "0.83 lb @ 1.99 /lb", "WT 1.55 lb". \
    They usually print under the item, but on some stores' receipts the weight/qty modifier prints \
    ABOVE the item it belongs to — attach it to whichever adjacent item makes the math work \
    (weight × rate = that item's price). Produce, meat, and bulk items are usually sold by weight. \
    NEVER default a by-weight item to quantity 1 — if a weight is printed, you MUST extract \
    weightLbs and pricePerLb.
    - Savings lines ("Member Savings", "Card Savings") sometimes print next to the WRONG item \
    (e.g. after a CRV deposit line). Attribute each saving to the item whose Price/You Pay \
    arithmetic it satisfies, not blindly to the preceding line.
    - Multi-buy deals ("2 for $5.00", "3 @ 2/$3.00"): set quantity to the units rung and \
    unitPrice to the average per unit so quantity × unitPrice = pricePaid.
    - Voided/cancelled lines: include as line_type "refund" with negative pricePaid.
    - lineType: classify each line as one of "item" (normal grocery product), \
    "deposit" (bottle/CRV deposit), "fee" (bag fee, service charge), \
    "refund" (bag refund, returns — pricePaid negative), \
    "discount" (a standalone discount/coupon line), \
    "non_grocery" (household goods, merchandise, clothing, plants, gift cards)
    - listPrice: the regular shelf price for this line total (before any sale/coupon)
    - pricePaid: the actual amount charged (after discounts); equal to listPrice when no discount
    - lineTotal: same as pricePaid
    - If listPrice cannot be distinguished from pricePaid, set both to the amount shown
    - barcode: include the PLU or UPC code if printed; null otherwise
    - category: copy the department label from the receipt if present; infer if not
    - Include EVERY line item: groceries, produce, deposits, fees, bag charges
    - null for any field that is genuinely absent from the receipt
    - SELF-CHECK before answering: the sum of pricePaid across all line items (plus tax, unless \
    tax is already a line) must equal total within $0.02. If it does not, re-read the receipt \
    for a missed line or misread digit, and prefer the digit reading that reconciles the total. \
    Lower confidence on any line you could not verify.
    - overallConfidence: 0.0–1.0 float reflecting your confidence in the overall extraction \
    (1.0 = perfectly legible receipt, 0.0 = nearly unreadable)
    - confidence (per item): 0.0–1.0 float reflecting confidence for that specific line \
    (lower when text is faded, truncated, or ambiguous)
    - Return ONLY the JSON object — no markdown fences, no explanation, no trailing text
    """
}

// MARK: - Request types

private struct ChatRequest: Encodable {
    let model:          String
    let messages:       [Message]
    let responseFormat: ResponseFormat
    let temperature:    Double
    let maxTokens:      Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case responseFormat = "response_format"
        case maxTokens      = "max_tokens"
    }

    struct Message: Encodable {
        let role:    String
        let content: [ContentPart]
    }

    enum ContentPart: Encodable {
        case text(String)
        case imageURL(dataURI: String)

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: PartKeys.self)
            switch self {
            case .text(let t):
                try c.encode("text", forKey: .type)
                try c.encode(t, forKey: .text)
            case .imageURL(let uri):
                try c.encode("image_url", forKey: .type)
                // detail:"high" uses more tiles for better small-text OCR on receipts
                struct ImageURL: Encodable { let url: String; let detail = "high" }
                try c.encode(ImageURL(url: uri), forKey: .imageURL)
            }
        }

        enum PartKeys: String, CodingKey {
            case type, text
            case imageURL = "image_url"
        }
    }

    struct ResponseFormat: Encodable { let type: String }
}
