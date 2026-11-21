import XCTest
@testable import BillMaker

final class LLMParsingTests: XCTestCase {
    var sampleCatalog: [Item] = []

    override func setUp() {
        super.setUp()
        sampleCatalog = [
            Item(name: "Potato", unitType: .kg, pricePerUnit: 30.0),
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0)
        ]
    }

    func testLLMPromptBuilderConstructsCatalogContextAndRules() {
        let systemPrompt = LLMPromptBuilder.buildSystemPrompt(catalog: sampleCatalog, currencySymbol: "₹")

        // Must contain inventory context
        XCTAssertTrue(systemPrompt.contains("STORE CATALOG:"))
        XCTAssertTrue(systemPrompt.contains("Potato"))
        XCTAssertTrue(systemPrompt.contains("Mustard Oil"))
        XCTAssertTrue(systemPrompt.contains("₹30.0"))
        XCTAssertTrue(systemPrompt.contains("₹160.0"))

        // Must contain critical rules
        XCTAssertTrue(systemPrompt.contains("Process ONLY the customer's current request"))
        XCTAssertTrue(systemPrompt.contains("<thought>...</thought>"))
        XCTAssertTrue(systemPrompt.contains("```json"))
    }

    func testLLMPromptBuilderChatMessages() {
        let messages = LLMPromptBuilder.buildChatMessages(
            userInput: "2kg aloo aur 1L tel",
            catalog: sampleCatalog,
            currencySymbol: "₹"
        )

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertEqual(messages[1]["content"], "2kg aloo aur 1L tel")
    }

    func testLLMResponseParserExtractsThoughtAndJSON() {
        let llmOutput = """
        <thought>
        1. Identified 2kg Potato from alias 'aloo'
        2. Computed subtotal: 2 * 30 = 60
        </thought>

        Added 2kg Potato to your bill.

        ```json
        {
          "status": "ready",
          "message": "Added 2kg Potato to your bill.",
          "thought": "Matched potato from catalog",
          "items": [
            {
              "itemId": "11111111-1111-1111-1111-111111111101",
              "itemName": "Potato",
              "matchedAlias": "aloo",
              "quantity": 2.0,
              "unit": "kg",
              "unitPrice": 30.0
            }
          ]
        }
        ```
        """

        let parsedMessage = LLMResponseParser.parse(
            content: llmOutput,
            catalog: sampleCatalog,
            settings: .defaultSettings
        )

        XCTAssertEqual(parsedMessage.status, .ready)
        XCTAssertEqual(parsedMessage.text, "Added 2kg Potato to your bill.")
        XCTAssertTrue(parsedMessage.thoughtProcess?.contains("Identified 2kg Potato") == true)
        XCTAssertNotNil(parsedMessage.rawJsonOutput)
        XCTAssertEqual(parsedMessage.parsedItems?.count, 1)
        XCTAssertEqual(parsedMessage.billSummary?.grandTotal, 60.0)
    }
}
