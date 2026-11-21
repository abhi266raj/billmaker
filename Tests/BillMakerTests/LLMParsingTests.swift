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

    func testLenientDecodingWithAppleFMStartOfTurnAndMultipleItems() {
        let rawAppleFMOutput = """
        <start_of_turn>model
        ```json
        {
          "status": "ready",
          "message": "2kg Potato and 1kg Tomato confirmed and ready to bill.",
          "items": [
            {
              "itemName": "Potato",
              "quantity": 2.0,
              "unit": "kg",
              "unitPrice": 30.0
            },
            {
              "itemName": "Tomato",
              "quantity": 1.0,
              "unit": "kg",
              "unitPrice": 40.0
            }
          ]
        }
        ```
        """

        let catalog = [
            Item(name: "Potato", unitType: .kg, pricePerUnit: 30.0),
            Item(name: "Tomato", unitType: .kg, pricePerUnit: 40.0)
        ]

        let parsedMessage = LLMResponseParser.parse(
            content: rawAppleFMOutput,
            catalog: catalog,
            settings: .defaultSettings
        )

        XCTAssertEqual(parsedMessage.status, .ready)
        XCTAssertEqual(parsedMessage.parsedItems?.count, 2)
        XCTAssertEqual(parsedMessage.billSummary?.grandTotal, 100.0) // (2*30) + (1*40) = 100
        XCTAssertEqual(parsedMessage.billSummary?.totalWeightKg, 3.0)
    }

    func testTopLevelArrayPayloadAndAlternateKeyNames() {
        let arrayOutput = """
        ```json
        [
          {
            "name": "Potato",
            "quantity": "2kg",
            "price": 30
          },
          {
            "item": "Mustard Oil",
            "qty": "500ml",
            "rate": 160
          }
        ]
        ```
        """

        let parsedMessage = LLMResponseParser.parse(
            content: arrayOutput,
            catalog: sampleCatalog,
            settings: .defaultSettings
        )

        XCTAssertEqual(parsedMessage.status, .ready)
        XCTAssertEqual(parsedMessage.parsedItems?.count, 2)
        let potato = parsedMessage.parsedItems?.first { $0.itemName == "Potato" }
        XCTAssertEqual(potato?.quantity, 2.0)
        XCTAssertEqual(potato?.unit, "kg")

        let oil = parsedMessage.parsedItems?.first { $0.itemName == "Mustard Oil" }
        XCTAssertEqual(oil?.quantity, 500.0)
        XCTAssertEqual(oil?.unit, "ml")
    }

    func testMissingJSONReturnsErrorAsRequired() {
        let plainTextOutput = "Sure! I have added 2kg Potato to your cart."

        let parsedMessage = LLMResponseParser.parse(
            content: plainTextOutput,
            catalog: sampleCatalog,
            settings: .defaultSettings
        )

        XCTAssertEqual(parsedMessage.status, .error)
        XCTAssertNil(parsedMessage.parsedItems)
        XCTAssertNil(parsedMessage.billSummary)
        XCTAssertNotNil(parsedMessage.thoughtProcess)
    }

    func testLiveDaemonIntegrationIfOnline() async throws {
        guard AppleFMServerManager.shared.isDaemonOnline() else { return }
        let catalog = [
            Item(name: "Potato", unitType: .kg, pricePerUnit: 30.0),
            Item(name: "Tomato", unitType: .kg, pricePerUnit: 40.0)
        ]
        let response = try await AppleFMServerManager.shared.queryDaemon(
            userInput: "2kg aloo aur 1kg tamatar",
            conversationHistory: [],
            catalog: catalog,
            currencySymbol: "₹"
        )
        let parsed = LLMResponseParser.parse(content: response, catalog: catalog, settings: .defaultSettings)
        XCTAssertEqual(parsed.status, .ready)
        XCTAssertNotNil(parsed.parsedItems)
        XCTAssertGreaterThanOrEqual(parsed.parsedItems?.count ?? 0, 1)
        XCTAssertNotNil(parsed.billSummary)
        let bill = BillCalculator.mergeIntoBill(
            existingBill: nil,
            newParsedItems: parsed.parsedItems ?? [],
            catalog: catalog
        )
        XCTAssertFalse(bill.items.isEmpty)
    }
}
