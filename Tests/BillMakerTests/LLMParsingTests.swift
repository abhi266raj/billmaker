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
        XCTAssertTrue(systemPrompt.contains("Context & Conversation Continuity"))
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

    func testClarificationPayloadWithEmptyItemsAsksForClarification() {
        let clarificationOutput = """
        ```json
        {
          "status": "ready",
          "message": "Mustard Oil is ₹160.0/L, but you requested 1 kg oil. Please confirm if you meant Mustard Oil (₹160.0/L) or another oil.",
          "thought": "The customer requested 1 kg oil, but the catalog lists Mustard Oil priced at ₹160.0/L, so I need clarification.",
          "items": []
        }
        ```
        """

        let catalog = [
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0)
        ]

        let parsedMessage = LLMResponseParser.parse(
            content: clarificationOutput,
            catalog: catalog,
            settings: .defaultSettings,
            userInput: "1kg oil"
        )

        // Verifies clarification questions are recognized as clarifications and never falsely auto-billed
        XCTAssertEqual(parsedMessage.status, .needsClarification)
        XCTAssertTrue(parsedMessage.text.contains("Mustard Oil"))
        XCTAssertEqual(parsedMessage.pendingClarification?.candidateNames.contains("Mustard Oil"), true)
    }

    func testItemNotFoundReturnsNotFoundStatus() {
        let notFoundJson = """
        ```json
        {
          "status": "not_found",
          "message": "Item 'salt' was not found in the store catalog.",
          "thought": "Salt is not available in the store catalog.",
          "items": []
        }
        ```
        """

        let parsedMessage = LLMResponseParser.parse(
            content: notFoundJson,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "1kg salt"
        )

        XCTAssertEqual(parsedMessage.status, .notFound)
        XCTAssertTrue(parsedMessage.text.contains("salt"))
        XCTAssertNil(parsedMessage.parsedItems)
        XCTAssertNil(parsedMessage.billSummary)
    }

    func testSaltRequestedInterceptsHallucinatedBasmatiRiceMapping() {
        let hallucinatedPayload = """
        ```json
        {
          "status": "ready",
          "message": "Added 1 kg Basmati Rice to the bill.",
          "thought": "Mapped salt to rice.",
          "items": [
            {
              "itemName": "Basmati Rice",
              "quantity": 1.0,
              "unit": "kg",
              "unitPrice": 110.0
            }
          ]
        }
        ```
        """

        let parsedMessage = LLMResponseParser.parse(
            content: hallucinatedPayload,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "1kg salt"
        )

        // Intercepts false match and converts to .notFound
        XCTAssertEqual(parsedMessage.status, .notFound)
        XCTAssertTrue(parsedMessage.text.contains("salt"))
        XCTAssertNil(parsedMessage.parsedItems)
        XCTAssertNil(parsedMessage.billSummary)
    }

    func testGenericOilQueryAsksClarificationInsteadOfAutoBilling() {
        let readyOilPayload = """
        ```json
        {
          "status": "ready",
          "message": "Added 1 L Mustard Oil to the bill.",
          "thought": "Assumed mustard oil.",
          "items": [
            {
              "itemName": "Mustard Oil",
              "quantity": 1.0,
              "unit": "L",
              "unitPrice": 160.0
            }
          ]
        }
        ```
        """

        let multiOilCatalog = [
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0),
            Item(name: "Sunflower Oil", unitType: .litre, pricePerUnit: 145.0)
        ]

        let parsedMessage = LLMResponseParser.parse(
            content: readyOilPayload,
            catalog: multiOilCatalog,
            settings: .defaultSettings,
            userInput: "1kg oil"
        )

        // Verifies that generic "oil" requests prompt for clarification rather than falsely guessing Mustard Oil
        XCTAssertEqual(parsedMessage.status, .needsClarification)
        XCTAssertTrue(parsedMessage.text.contains("oil") || parsedMessage.text.contains("Oil"))
        XCTAssertNotNil(parsedMessage.pendingClarification)
        XCTAssertTrue(parsedMessage.pendingClarification?.candidateNames.contains("Mustard Oil") == true)
        XCTAssertTrue(parsedMessage.pendingClarification?.candidateNames.contains("Sunflower Oil") == true)
    }

    func testUnambiguousMustardOilQueryBillsDirectly() {
        let readyOilPayload = """
        ```json
        {
          "status": "ready",
          "message": "Added 1 L Mustard Oil to the bill.",
          "thought": "Direct match for mustard oil.",
          "items": [
            {
              "itemName": "Mustard Oil",
              "quantity": 1.0,
              "unit": "L",
              "unitPrice": 160.0
            }
          ]
        }
        ```
        """

        let parsedMessage = LLMResponseParser.parse(
            content: readyOilPayload,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "1L mustard oil"
        )

        XCTAssertEqual(parsedMessage.status, .ready)
        XCTAssertEqual(parsedMessage.parsedItems?.count, 1)
        XCTAssertEqual(parsedMessage.parsedItems?.first?.itemName, "Mustard Oil")
        XCTAssertEqual(parsedMessage.billSummary?.grandTotal, 160.0)
    }

    func testClarificationResolvedDirectlyWhenUserSelectsOrTypesSunflowerOil() {
        let clarificationJson = """
        ```json
        {
          "status": "needs_clarification",
          "message": "Which oil would you like? We have Mustard Oil (₹160.0/L) and Sunflower Oil (₹145.0/L).",
          "thought": "Ambiguous oil requested with multiple candidate matches; asking for clarification.",
          "options": ["Mustard Oil", "Sunflower Oil"],
          "pendingClarification": {
            "query": "oil",
            "quantity": 1.0,
            "unit": "L",
            "candidateNames": ["Mustard Oil", "Sunflower Oil"]
          }
        }
        ```
        """

        let multiOilCatalog = [
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0),
            Item(name: "Sunflower Oil", unitType: .litre, pricePerUnit: 145.0)
        ]

        let parsedMessage = LLMResponseParser.parse(
            content: clarificationJson,
            catalog: multiOilCatalog,
            settings: .defaultSettings,
            userInput: "Sunflower Oil"
        )

        // Verifies that specifying "Sunflower Oil" overrides redundant clarification and resolves directly to ready
        XCTAssertEqual(parsedMessage.status, .ready)
        XCTAssertEqual(parsedMessage.parsedItems?.count, 1)
        XCTAssertEqual(parsedMessage.parsedItems?.first?.itemName, "Sunflower Oil")
        XCTAssertEqual(parsedMessage.billSummary?.grandTotal, 145.0)
    }

    func testColloquialQuantitiesAndNumeralsNormalization() {
        XCTAssertEqual(ItemCatalogMatcher.normalizeNumerals("२ किलो"), "2 किलो")
        XCTAssertEqual(ItemCatalogMatcher.normalizeColloquials("dedh kilo aloo"), "1.5 kg aloo")
        XCTAssertEqual(ItemCatalogMatcher.normalizeColloquials("aadha kilo tamatar"), "0.5 kg tamatar")
        XCTAssertEqual(ItemCatalogMatcher.normalizeColloquials("dhai sau gram adrak"), "250g adrak")
    }

    func testClarificationChoiceResolutionWithOrdinalsAndNames() {
        let catalog = [
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0),
            Item(name: "Sunflower Oil", unitType: .litre, pricePerUnit: 145.0)
        ]
        let pending = PendingClarification(
            query: "oil",
            quantity: 2.0,
            unit: "L",
            candidateNames: ["Mustard Oil", "Sunflower Oil"]
        )

        // Test ordinal "first"
        let res1 = ItemCatalogMatcher.resolveClarificationChoice(userInput: "first", pending: pending, catalog: catalog)
        XCTAssertEqual(res1?.item.name, "Mustard Oil")
        XCTAssertEqual(res1?.quantity, 2.0)

        // Test ordinal "2nd"
        let res2 = ItemCatalogMatcher.resolveClarificationChoice(userInput: "2nd", pending: pending, catalog: catalog)
        XCTAssertEqual(res2?.item.name, "Sunflower Oil")
        XCTAssertEqual(res2?.quantity, 2.0)

        // Test colloquial "surajmukhi"
        let res3 = ItemCatalogMatcher.resolveClarificationChoice(userInput: "surajmukhi", pending: pending, catalog: catalog)
        XCTAssertEqual(res3?.item.name, "Sunflower Oil")

        // Test affirmation "haan" confirms first candidate
        let res4 = ItemCatalogMatcher.resolveClarificationChoice(userInput: "haan", pending: pending, catalog: catalog)
        XCTAssertEqual(res4?.item.name, "Mustard Oil")
    }

    func testMultiItemPartialMatchBillsValidItemAndExcludesUnlisted() {
        let multiPayload = """
        ```json
        {
          "status": "ready",
          "message": "Added 2 kg Potato and 1 kg Basmati Rice",
          "items": [
            {
              "itemName": "Potato",
              "quantity": 2.0,
              "unit": "kg",
              "unitPrice": 30.0
            },
            {
              "itemName": "Basmati Rice",
              "quantity": 1.0,
              "unit": "kg",
              "unitPrice": 110.0
            }
          ]
        }
        ```
        """

        let parsedMessage = LLMResponseParser.parse(
            content: multiPayload,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato aur 1kg salt"
        )

        // Potato was valid and must be billed; hallucinated Basmati Rice for 'salt' must be excluded!
        XCTAssertEqual(parsedMessage.status, .ready)
        XCTAssertEqual(parsedMessage.parsedItems?.count, 1)
        XCTAssertEqual(parsedMessage.parsedItems?.first?.itemName, "Potato")
        XCTAssertEqual(parsedMessage.billSummary?.grandTotal, 60.0)
        XCTAssertTrue(parsedMessage.text.contains("Potato"))
        XCTAssertTrue(parsedMessage.text.contains("Note:"))
    }

    func testStructuredClarificationJSONParsingWithCandidateOptions() {
        let clarificationJson = """
        ```json
        {
          "status": "needs_clarification",
          "message": "Which oil would you like? We have Mustard Oil and Sunflower Oil.",
          "thought": "Ambiguous oil requested with multiple candidate matches",
          "options": ["Mustard Oil", "Sunflower Oil"],
          "pendingClarification": {
            "query": "oil",
            "quantity": 1.0,
            "unit": "L",
            "candidateNames": ["Mustard Oil", "Sunflower Oil"]
          }
        }
        ```
        """

        let parsedMessage = LLMResponseParser.parse(
            content: clarificationJson,
            catalog: sampleCatalog,
            settings: .defaultSettings
        )

        XCTAssertEqual(parsedMessage.status, .needsClarification)
        XCTAssertEqual(parsedMessage.text, "Which oil would you like? We have Mustard Oil and Sunflower Oil.")
        XCTAssertNotNil(parsedMessage.pendingClarification)
        XCTAssertEqual(parsedMessage.pendingClarification?.candidateNames.count, 2)
        XCTAssertTrue(parsedMessage.pendingClarification?.candidateNames.contains("Mustard Oil") == true)
        XCTAssertTrue(parsedMessage.pendingClarification?.candidateNames.contains("Sunflower Oil") == true)
    }

    func testDiagnosticsLoggerCapturesFailureTelemetry() {
        let malformedJson = """
        ```json
        {
          "status": "ready",
          "items": "not-an-array"
        }
        ```
        """

        _ = LLMResponseParser.parse(
            content: malformedJson,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg apple test"
        )

        let records = ParsingDiagnosticsLogger.shared.recentRecords
        guard let latestRecord = records.first else {
            XCTFail("Diagnostics record was not recorded")
            return
        }

        XCTAssertEqual(latestRecord.outcome, .decodingError)
        XCTAssertTrue(latestRecord.isFailure)
        XCTAssertEqual(latestRecord.userInput, "2kg apple test")
        XCTAssertTrue(latestRecord.extractedJson?.contains("not-an-array") == true)
        XCTAssertNotNil(latestRecord.rootCauseAnalysis)
    }

    func testDiagnosticsLoggerCapturesMissingJsonTelemetry() {
        let plainText = "I have added nothing because no JSON exists here."

        _ = LLMResponseParser.parse(
            content: plainText,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "hello world"
        )

        let records = ParsingDiagnosticsLogger.shared.recentRecords
        guard let latestRecord = records.first else {
            XCTFail("Diagnostics record was not recorded")
            return
        }

        XCTAssertEqual(latestRecord.outcome, .missingJson)
        XCTAssertTrue(latestRecord.isFailure)
        XCTAssertEqual(latestRecord.userInput, "hello world")
        XCTAssertNil(latestRecord.extractedJson)
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
