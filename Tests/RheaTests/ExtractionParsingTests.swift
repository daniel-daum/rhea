import Testing
import Foundation
@testable import Rhea

/// Table-driven coverage for the two "parsing armor" layers that every extraction
/// passes through before it reaches the UI:
///   - `ExtractionService.extractJSON` — pulls a JSON object out of raw model output
///     (code fences, leading/trailing prose, nested braces).
///   - `LenientDecoding` (via `LineItem`/`ExtractedReceipt` custom `init(from:)`) —
///     coerces off-type values (quoted/prefixed numbers, numeric strings, bools-as-strings)
///     and maps the legacy `commonName` key onto `aiCommonName`.
/// Regressions here silently corrupt every future extraction, so these are tested
/// directly against fixture strings rather than only through the network round trip
/// covered by `SyntheticFixtureTests`.
struct ExtractionParsingTests {

    // MARK: - extractJSON

    struct ExtractJSONCase {
        let name: String
        let raw: String
        let expectedJSON: String
    }

    static let extractJSONCases: [ExtractJSONCase] = [
        ExtractJSONCase(
            name: "unfenced, no prose",
            raw: #"{"merchant":"TESTMART"}"#,
            expectedJSON: #"{"merchant":"TESTMART"}"#
        ),
        ExtractJSONCase(
            name: "fenced with json tag",
            raw: "```json\n{\"merchant\":\"TESTMART\"}\n```",
            expectedJSON: #"{"merchant":"TESTMART"}"#
        ),
        ExtractJSONCase(
            name: "fenced with bare tag",
            raw: "```\n{\"merchant\":\"TESTMART\"}\n```",
            expectedJSON: #"{"merchant":"TESTMART"}"#
        ),
        ExtractJSONCase(
            name: "leading prose",
            raw: "Here is the extracted receipt data:\n\n{\"merchant\":\"TESTMART\"}",
            expectedJSON: #"{"merchant":"TESTMART"}"#
        ),
        ExtractJSONCase(
            name: "trailing prose",
            raw: "{\"merchant\":\"TESTMART\"}\n\nLet me know if you need anything else.",
            expectedJSON: #"{"merchant":"TESTMART"}"#
        ),
        ExtractJSONCase(
            name: "leading and trailing prose",
            raw: "Sure, here you go:\n{\"merchant\":\"TESTMART\"}\nHope that helps!",
            expectedJSON: #"{"merchant":"TESTMART"}"#
        ),
        ExtractJSONCase(
            name: "nested braces in string values",
            raw: #"{"merchant":"TESTMART {flagship}","note":"see {details} below"}"#,
            expectedJSON: #"{"merchant":"TESTMART {flagship}","note":"see {details} below"}"#
        ),
        ExtractJSONCase(
            name: "nested object values",
            raw: #"{"merchant":"TESTMART","meta":{"aisle":3,"tags":{"a":1}}}"#,
            expectedJSON: #"{"merchant":"TESTMART","meta":{"aisle":3,"tags":{"a":1}}}"#
        ),
    ]

    @Test(arguments: extractJSONCases)
    func extractJSONLocatesObject(testCase: ExtractJSONCase) throws {
        let data = try #require(ExtractionService.extractJSON(from: testCase.raw))
        let got = try #require(String(data: data, encoding: .utf8))
        #expect(got == testCase.expectedJSON)

        // The extracted slice must itself be valid, decodable JSON.
        #expect(throws: Never.self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }

    @Test
    func extractJSONPassesRawTextThroughWhenNoBracesPresent() throws {
        // No `{`/`}` at all: the outermost-braces slice is skipped and the trimmed
        // raw text is returned as-is (not nil) — it will simply fail to decode as
        // JSON downstream, which callers already handle via ExtractionError.parseError.
        let data = try #require(ExtractionService.extractJSON(from: "no json here at all"))
        #expect(String(data: data, encoding: .utf8) == "no json here at all")
        #expect(throws: (any Error).self) {
            _ = try JSONSerialization.jsonObject(with: data)
        }
    }

    // MARK: - Lenient decoding: prices

    private struct PriceHolder: Decodable {
        let value: Decimal?
        enum CodingKeys: String, CodingKey { case value }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.value = c.lenientDecimal(.value)
        }
    }

    struct PriceCase {
        let name: String
        let json: String
        let expected: Decimal?
    }

    static let priceCases: [PriceCase] = [
        PriceCase(name: "plain number", json: #"{"value":4.98}"#, expected: Decimal(string: "4.98")),
        PriceCase(name: "dollar-prefixed string", json: #"{"value":"$4.98"}"#, expected: Decimal(string: "4.98")),
        PriceCase(name: "comma thousands string", json: #"{"value":"1,024.00"}"#, expected: Decimal(string: "1024.00")),
        PriceCase(name: "dollar + comma string", json: #"{"value":"$1,024.00"}"#, expected: Decimal(string: "1024.00")),
        PriceCase(name: "number as plain string", json: #"{"value":"4.98"}"#, expected: Decimal(string: "4.98")),
        PriceCase(name: "integer as string", json: #"{"value":"12"}"#, expected: Decimal(string: "12")),
        PriceCase(name: "whitespace padded string", json: #"{"value":" 4.98 "}"#, expected: Decimal(string: "4.98")),
        PriceCase(name: "explicit null", json: #"{"value":null}"#, expected: nil),
        PriceCase(name: "missing key", json: #"{}"#, expected: nil),
        PriceCase(name: "bool-as-string is not a price", json: #"{"value":"true"}"#, expected: nil),
        PriceCase(name: "non-numeric garbage string", json: #"{"value":"N/A"}"#, expected: nil),
    ]

    @Test(arguments: priceCases)
    func lenientDecimalCoercesKnownShapes(testCase: PriceCase) throws {
        let data = try #require(testCase.json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(PriceHolder.self, from: data)
        #expect(decoded.value == testCase.expected)
    }

    // MARK: - Lenient decoding: strings (numbers-as-strings, bools-as-strings)

    private struct StringHolder: Decodable {
        let value: String?
        enum CodingKeys: String, CodingKey { case value }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.value = c.lenientString(.value)
        }
    }

    struct StringCase {
        let name: String
        let json: String
        let expected: String?
    }

    static let stringCases: [StringCase] = [
        StringCase(name: "plain string", json: #"{"value":"4021"}"#, expected: "4021"),
        StringCase(name: "integer coerced to string", json: #"{"value":4021}"#, expected: "4021"),
        StringCase(name: "decimal coerced to string", json: #"{"value":41000000123}"#, expected: "41000000123"),
        StringCase(name: "bool coerced to string", json: #"{"value":true}"#, expected: "true"),
        StringCase(name: "empty string becomes nil", json: #"{"value":""}"#, expected: nil),
        StringCase(name: "whitespace-only string becomes nil", json: #"{"value":"   "}"#, expected: nil),
        StringCase(name: "explicit null", json: #"{"value":null}"#, expected: nil),
        StringCase(name: "missing key", json: #"{}"#, expected: nil),
    ]

    @Test(arguments: stringCases)
    func lenientStringCoercesKnownShapes(testCase: StringCase) throws {
        let data = try #require(testCase.json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(StringHolder.self, from: data)
        #expect(decoded.value == testCase.expected)
    }

    // MARK: - Legacy commonName -> aiCommonName mapping

    @Test
    func legacyCommonNameMapsToAICommonName() throws {
        let json = #"{"name":"ORGANIC BANANAS","commonName":"organic bananas"}"#
        let data = try #require(json.data(using: .utf8))
        let item = try JSONDecoder().decode(LineItem.self, from: data)
        #expect(item.aiCommonName == "organic bananas")
    }

    @Test
    func explicitAICommonNameTakesPrecedenceOverLegacyCommonName() throws {
        let json = #"{"name":"ORGANIC BANANAS","aiCommonName":"bananas","commonName":"legacy bananas"}"#
        let data = try #require(json.data(using: .utf8))
        let item = try JSONDecoder().decode(LineItem.self, from: data)
        #expect(item.aiCommonName == "bananas")
    }

    @Test
    func missingCommonNameLeavesAICommonNameNil() throws {
        let json = #"{"name":"ORGANIC BANANAS"}"#
        let data = try #require(json.data(using: .utf8))
        let item = try JSONDecoder().decode(LineItem.self, from: data)
        #expect(item.aiCommonName == nil)
    }

    // MARK: - Null pricePaid rows survive decoding

    /// 8 differently-shaped rows the vision model has been observed to emit when it
    /// can't determine a paid price. Each should decode to a `LineItem` with
    /// `pricePaid == nil` (and `effectivePricePaid` falling back to `lineTotal` when
    /// present) rather than throwing or crashing the whole receipt.
    static let nullPricePaidRows: [String] = [
        // 1. explicit null
        #"{"name":"ITEM A","pricePaid":null,"lineTotal":1.99}"#,
        // 2. key omitted entirely
        #"{"name":"ITEM B","lineTotal":2.49}"#,
        // 3. empty string
        #"{"name":"ITEM C","pricePaid":"","lineTotal":3.29}"#,
        // 4. whitespace-only string
        #"{"name":"ITEM D","pricePaid":"   ","lineTotal":4.19}"#,
        // 5. non-numeric garbage string
        #"{"name":"ITEM E","pricePaid":"N/A","lineTotal":5.00}"#,
        // 6. literal "null" string (model quoting the word itself)
        #"{"name":"ITEM F","pricePaid":"null","lineTotal":6.50}"#,
        // 7. bool false where a price was expected
        #"{"name":"ITEM G","pricePaid":false,"lineTotal":7.75}"#,
        // 8. no lineTotal either — pricePaid and effectivePricePaid both nil
        #"{"name":"ITEM H","pricePaid":null}"#,
    ]

    @Test(arguments: nullPricePaidRows)
    func nullPricePaidRowsDecodeToNilWithoutThrowing(rowJSON: String) throws {
        let data = try #require(rowJSON.data(using: .utf8))
        let item = try JSONDecoder().decode(LineItem.self, from: data)
        #expect(item.pricePaid == nil)
        #expect(!item.name.isEmpty)
    }

    // MARK: - Malformed line item doesn't sink the receipt

    @Test
    func malformedLineItemDoesNotThrowForWholeReceipt() throws {
        // One entry in lineItems is a bare string instead of an object — structurally
        // invalid, not just off-type. LineItem's container(keyedBy:) throws for it,
        // which fails array decoding as a whole; ExtractedReceipt.init(from:) catches
        // that with `try?` and falls back to an empty array rather than propagating
        // the error and losing the entire receipt (merchant/total/etc. still decode).
        let json = """
        {
          "merchant": "TESTMART #4021",
          "total": 9.99,
          "lineItems": [
            {"name": "GOOD ITEM", "pricePaid": 1.99},
            "this is not a line item object",
            {"name": "ANOTHER GOOD ITEM", "pricePaid": 2.99}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))

        let receipt = try JSONDecoder().decode(ExtractedReceipt.self, from: data)

        #expect(receipt.merchant == "TESTMART #4021")
        #expect(receipt.total == Decimal(string: "9.99"))
        // Documents current all-or-nothing fallback: a structurally malformed element
        // drops the whole array rather than crashing the receipt decode.
        #expect(receipt.lineItems.isEmpty)
    }

    @Test
    func lineItemWithOffTypeFieldsStillDecodesAlongsideValidSiblings() throws {
        // Off-type (not structurally invalid) fields are individually coerced by
        // LenientDecoding, so a "malformed" item in this sense does NOT sink its
        // siblings — all three items survive.
        let json = """
        {
          "merchant": "TESTMART #4021",
          "total": 9.99,
          "lineItems": [
            {"name": "GOOD ITEM", "pricePaid": 1.99},
            {"name": "WEIRD TYPES ITEM", "pricePaid": "$2.99", "barcode": 123456789, "quantity": "2"},
            {"name": "ANOTHER GOOD ITEM", "pricePaid": 2.99}
          ]
        }
        """
        let data = try #require(json.data(using: .utf8))

        let receipt = try JSONDecoder().decode(ExtractedReceipt.self, from: data)

        #expect(receipt.lineItems.count == 3)
        #expect(receipt.lineItems[1].pricePaid == Decimal(string: "2.99"))
        #expect(receipt.lineItems[1].barcode == "123456789")
        #expect(receipt.lineItems[1].quantity == Decimal(string: "2"))
    }
}
