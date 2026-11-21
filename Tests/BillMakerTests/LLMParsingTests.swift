import XCTest
import TypeDecoder
#if canImport(AgentAtomSource)
import AgentAtomSource
#endif
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

    func testBillingSpecConstructsCatalogContextAndRules() {
        let input = BillingInput(
            request: "2kg aloo aur 1L tel",
            catalog: sampleCatalog,
            currencySymbol: "₹"
        )
        let spec = BillingSpec(input: input)
        let systemPrompt = spec.instructions

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

    func testBillingInputJsonAndPreviousContext() {
        let input = BillingInput(
            request: "2kg aloo aur 1L tel",
            catalog: sampleCatalog,
            currencySymbol: "₹",
            previousContext: "User: 1L oil\nAgent: Which oil?",
            asJSON: true
        )
        let spec = BillingSpec(input: input)

        XCTAssertTrue(input.catalogSummary.contains("\"name\" : \"Potato\"") || input.catalogSummary.contains("\"name\":\"Potato\""))
        XCTAssertTrue(spec.instructions.contains("PREVIOUS CONVERSATION CONTEXT:"))
        XCTAssertTrue(spec.instructions.contains("Which oil?"))
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

    func testUnifiedObjectItemsFormatWithVerifiedObjectDictionary() {
        let json = """
        ```json
        {
          "thought": "Customer requested 2kg potato.",
          "message": "Added 2 kg Potato.",
          "items": {
            "verified": {
              "Potato": {
                "quantity": 2.0,
                "unit": "kg",
                "unitPrice": 30.0
              }
            },
            "rejected": {},
            "needClarification": {}
          }
        }
        ```
        """

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato"
        )

        XCTAssertEqual(parsed.status, .ready)
        XCTAssertEqual(parsed.parsedItems?.count, 1)
        XCTAssertEqual(parsed.parsedItems?.first?.itemName, "Potato")
        XCTAssertEqual(parsed.parsedItems?.first?.quantity, 2.0)
        XCTAssertEqual(parsed.parsedItems?.first?.unit, "kg")
        XCTAssertNotNil(parsed.billSummary)
    }

    func testUnifiedObjectItemsFormatWithRejectedObjectDictionary() {
        let json = """
        ```json
        {
          "thought": "Salt is not in store catalog.",
          "message": "Item 'salt' not found in store catalog.",
          "items": {
            "verified": {},
            "rejected": {
              "salt": {
                "reason": "Not in store catalog"
              }
            },
            "needClarification": {}
          }
        }
        ```
        """

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "1kg salt"
        )

        XCTAssertEqual(parsed.status, .notFound)
        XCTAssertTrue(parsed.text.contains("salt"))
        XCTAssertNil(parsed.parsedItems)
    }

    func testUnifiedObjectItemsFormatWithNeedClarificationObjectDictionary() {
        let json = """
        ```json
        {
          "thought": "Customer asked for generic oil, multiple oils exist.",
          "message": "Which oil would you like? We have Mustard Oil and Sunflower Oil.",
          "items": {
            "verified": {},
            "rejected": {},
            "needClarification": {
              "oil": {
                "quantity": 1.0,
                "unit": "L",
                "options": ["Mustard Oil", "Sunflower Oil"],
                "reason": "Multiple matching options in catalog"
              }
            }
          }
        }
        ```
        """

        let catalog = [
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0),
            Item(name: "Sunflower Oil", unitType: .litre, pricePerUnit: 140.0)
        ]

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: catalog,
            settings: .defaultSettings,
            userInput: "1 litre oil"
        )

        XCTAssertEqual(parsed.status, .needsClarification)
        XCTAssertNotNil(parsed.pendingClarification)
        XCTAssertTrue(parsed.pendingClarification?.candidateNames.contains("Mustard Oil") == true)
        XCTAssertTrue(parsed.pendingClarification?.candidateNames.contains("Sunflower Oil") == true)
    }

    func testUnifiedObjectItemsFormatWithSingleItemObjects() {
        let json = """
        ```json
        {
          "thought": "Customer requested 2kg potato.",
          "message": "Added 2 kg Potato.",
          "items": {
            "verified": {
              "itemName": "Potato",
              "quantity": 2.0,
              "unit": "kg",
              "unitPrice": 30.0
            },
            "rejected": {},
            "needClarification": {}
          }
        }
        ```
        """

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato"
        )

        XCTAssertEqual(parsed.status, .ready)
        XCTAssertEqual(parsed.parsedItems?.count, 1)
        XCTAssertEqual(parsed.parsedItems?.first?.itemName, "Potato")
        XCTAssertEqual(parsed.parsedItems?.first?.quantity, 2.0)
    }

    func testMixedVerifiedAndRejectedObjects() {
        let json = """
        ```json
        {
          "thought": "Potato is in catalog, salt is not.",
          "message": "Added 2 kg Potato.",
          "items": {
            "verified": {
              "Potato": {
                "quantity": 2.0,
                "unit": "kg",
                "unitPrice": 30.0
              }
            },
            "rejected": {
              "salt": "Not in store catalog"
            },
            "needClarification": {}
          }
        }
        ```
        """

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato aur 1 packet salt"
        )

        XCTAssertEqual(parsed.status, .ready)
        XCTAssertEqual(parsed.parsedItems?.count, 1)
        XCTAssertEqual(parsed.parsedItems?.first?.itemName, "Potato")
        XCTAssertTrue(parsed.text.contains("salt") || parsed.thoughtProcess?.contains("salt") == true)
    }

    func testAgentAtomBillingSpecConstruction() {
        let schema = JSONSchema(AgentAtomBillingOutput.self)
        XCTAssertNotNil(schema)
        XCTAssertTrue(schema?.rawValue.contains("verified") == true)
        XCTAssertTrue(schema?.rawValue.contains("rejected") == true)
        XCTAssertTrue(schema?.rawValue.contains("needClarification") == true)
    }

    func testMultipleItemsParsedFullyFromObjectDictionary() {
        let json = """
        ```json
        {
          "thought": "Parsed multiple items from grocery order.",
          "message": "Added 2 kg Potato, 1 kg Tomato, and 1 L Cow Milk to your bill.",
          "items": {
            "verified": {
              "Potato": {
                "quantity": 2.0,
                "unit": "kg",
                "unitPrice": 30.0
              },
              "Tomato": {
                "quantity": 1.0,
                "unit": "kg",
                "unitPrice": 40.0
              },
              "Cow Milk": {
                "quantity": 1.0,
                "unit": "L",
                "unitPrice": 64.0
              }
            },
            "rejected": {},
            "needClarification": {}
          }
        }
        ```
        """

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato, 1kg tomato aur 1 litre doodh"
        )

        XCTAssertEqual(parsed.status, .ready)
        XCTAssertEqual(parsed.parsedItems?.count, 3)
        let itemNames = Set(parsed.parsedItems?.map(\.itemName) ?? [])
        XCTAssertTrue(itemNames.contains("Potato"))
        XCTAssertTrue(itemNames.contains("Tomato"))
        XCTAssertTrue(itemNames.contains("Cow Milk"))
        XCTAssertNotNil(parsed.billSummary)
        // Subtotals: Potato (2*30=60), Tomato (1*40=40), Milk (1*64=64) => Total subtotal: 164
        XCTAssertEqual(parsed.billSummary?.subtotal, 164.0)
    }

    func testMultipleItemsWithSimpleQuantityDictionary() {
        let json = """
        ```json
        {
          "thought": "Parsed numeric dictionary.",
          "message": "Added items.",
          "items": {
            "verified": {
              "Potato": 2.0,
              "Tomato": 1.5
            },
            "rejected": {},
            "needClarification": {}
          }
        }
        ```
        """

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato aur dedh kilo tomato"
        )

        XCTAssertEqual(parsed.status, .ready)
        XCTAssertEqual(parsed.parsedItems?.count, 2)
        let itemNames = Set(parsed.parsedItems?.map(\.itemName) ?? [])
        XCTAssertTrue(itemNames.contains("Potato"))
        XCTAssertTrue(itemNames.contains("Tomato"))
    }

    func testMultiItemRequestWithMixedVerifiedAndClarificationPreservesVerifiedItems() {
        let json = """
        ```json
        {
          "thought": "Potato is verified, oil needs variety choice.",
          "message": "Added 2 kg Potato. Which oil would you like? We have Mustard Oil and Sunflower Oil.",
          "items": {
            "verified": {
              "Potato": {
                "quantity": 2.0,
                "unit": "kg",
                "unitPrice": 30.0
              }
            },
            "rejected": {},
            "needClarification": {
              "oil": {
                "quantity": 1.0,
                "unit": "L",
                "options": ["Mustard Oil", "Sunflower Oil"],
                "reason": "Multiple oil varieties available"
              }
            }
          }
        }
        ```
        """

        let catalog = [
            Item(name: "Potato", unitType: .kg, pricePerUnit: 30.0),
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0),
            Item(name: "Sunflower Oil", unitType: .litre, pricePerUnit: 145.0)
        ]

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: catalog,
            settings: .defaultSettings,
            userInput: "2kg potato aur 1 litre tel"
        )

        XCTAssertEqual(parsed.status, .needsClarification)
        // Verified items MUST NOT be nil or discarded
        XCTAssertEqual(parsed.parsedItems?.count, 1)
        XCTAssertEqual(parsed.parsedItems?.first?.itemName, "Potato")
        XCTAssertNotNil(parsed.billSummary)
        XCTAssertEqual(parsed.billSummary?.subtotal, 60.0)
        XCTAssertNotNil(parsed.pendingClarification)
        XCTAssertTrue(parsed.pendingClarification?.candidateNames.contains("Mustard Oil") == true)
        XCTAssertTrue(parsed.canUndo)
    }

    func testShortenedMultiItemNamesMatchCatalogCorrectly() {
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()
        let parsedAtta = AgentParsedItem(itemName: "Atta", quantity: 5.0, unit: "kg")
        let parsedMaggi = AgentParsedItem(itemName: "Maggi", quantity: 2.0, unit: "packet")
        let parsedMilk = AgentParsedItem(itemName: "Milk", quantity: 1.0, unit: "litre")
        let parsedRice = AgentParsedItem(itemName: "Rice", quantity: 2.0, unit: "kg")

        let billedAtta = BillCalculator.computeSingleItem(parsed: parsedAtta, catalog: fullCatalog)
        let billedMaggi = BillCalculator.computeSingleItem(parsed: parsedMaggi, catalog: fullCatalog)
        let billedMilk = BillCalculator.computeSingleItem(parsed: parsedMilk, catalog: fullCatalog)
        let billedRice = BillCalculator.computeSingleItem(parsed: parsedRice, catalog: fullCatalog)

        XCTAssertEqual(billedAtta.name, "Atta (Wheat Flour)")
        XCTAssertEqual(billedAtta.unitPrice, 42.0)
        XCTAssertEqual(billedMaggi.name, "Maggi Noodles")
        XCTAssertEqual(billedMaggi.unitPrice, 14.0)
        XCTAssertEqual(billedMilk.name, "Cow Milk")
        XCTAssertEqual(billedMilk.unitPrice, 64.0)
        XCTAssertEqual(billedRice.name, "Basmati Rice")
        XCTAssertEqual(billedRice.unitPrice, 110.0)
    }

    func testAgentAtomBillingOutputConvertsMultipleItemsProperly() {
        var container = AgentAtomItemsContainer()
        container.verified["Potato"] = AgentAtomVerifiedItem(quantity: 2.0, unit: "kg", unitPrice: 30.0)
        container.verified["Tomato"] = AgentAtomVerifiedItem(quantity: 1.0, unit: "kg", unitPrice: 40.0)
        container.rejected["salt"] = AgentAtomRejectedItem(reason: "Not in store catalog")
        container.needClarification["oil"] = AgentAtomClarificationItem(quantity: 1.0, unit: "L", options: ["Mustard Oil", "Sunflower Oil"], reason: "Multiple options")

        let output = AgentAtomBillingOutput(
            thought: "Multi-item output test",
            message: "Added items with 1 unlisted and 1 ambiguous",
            items: container
        )

        let payload = output.toAgentJsonPayload()
        XCTAssertEqual(payload.items?.count, 2)
        XCTAssertEqual(payload.rejected?.count, 1)
        XCTAssertEqual(payload.needClarification?.count, 1)
        XCTAssertEqual(payload.status, "needs_clarification")
    }

    func testSessionAndAllRecordsDiagnosticsScopingAndClearing() {
        let logger = ParsingDiagnosticsLogger.shared
        logger.clearAllLogs()

        XCTAssertTrue(logger.sessionRecords.isEmpty)
        XCTAssertTrue(logger.allRecords.isEmpty)

        logger.log(
            userInput: "test input",
            rawLLMOutput: "test output",
            outcome: .success,
            rootCauseAnalysis: "session test"
        )

        XCTAssertEqual(logger.sessionRecords.count, 1)
        XCTAssertEqual(logger.allRecords.count, 1)

        // Clear only this session
        logger.clearSessionLogs()
        XCTAssertEqual(logger.sessionRecords.count, 0)
        XCTAssertEqual(logger.allRecords.count, 1) // allRecords preserved
    }

    func testVerifiedItemGivenInMessageAndUpdatedDuringClarification() {
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()
        let json = """
        ```json
        {
          "thought": "Customer requested 5kg atta and 1L oil.",
          "message": "Which oil would you like? We have Mustard Oil or Sunflower Oil.",
          "items": {
            "verified": {
              "Atta": {
                "quantity": 5.0,
                "unit": "kg",
                "unitPrice": 42.0
              }
            },
            "rejected": {},
            "needClarification": {
              "oil": {
                "quantity": 1.0,
                "unit": "L",
                "options": ["Mustard Oil", "Sunflower Oil"],
                "reason": "Specify variety"
              }
            }
          }
        }
        ```
        """

        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: fullCatalog,
            settings: .defaultSettings,
            userInput: "5kg atta and 1L oil"
        )

        XCTAssertEqual(parsed.status, .needsClarification)
        XCTAssertEqual(parsed.parsedItems?.count, 1)
        XCTAssertEqual(parsed.parsedItems?.first?.itemName, "Atta")
        XCTAssertNotNil(parsed.billSummary)
        XCTAssertTrue(parsed.text.contains("Added 5 kg Atta to the bill"))
        XCTAssertTrue(parsed.text.contains("Which oil would you like"))
    }

    func testDiagnosticsCapturesFatalSyntaxCorruption() {
        ParsingDiagnosticsLogger.shared.clearAllLogs()

        let corruptJson = """
        ```json
        {
          "status": "ready",
          "items": [{ "itemName": "Potato", "quantity": %$$# INVALID_CORRUPT_TOKEN
        }
        ```
        """

        let result = LLMResponseParser.parse(
            content: corruptJson,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg aloo syntax error test"
        )

        XCTAssertEqual(result.status, .error)

        let records = ParsingDiagnosticsLogger.shared.recentRecords
        guard let record = records.first else {
            XCTFail("Diagnostics record not logged for syntax corruption")
            return
        }

        XCTAssertEqual(record.outcome, .decodingError)
        XCTAssertTrue(record.isFailure)
        XCTAssertTrue(record.rootCauseAnalysis.contains("JSON syntax corrupted") || record.rootCauseAnalysis.contains("not valid JSON"))
        XCTAssertEqual(record.userInput, "2kg aloo syntax error test")
        XCTAssertNotNil(record.extractedJson)
    }

    func testDiagnosticsAutoRescuesTrailingCommaSyntaxCorruption() {
        ParsingDiagnosticsLogger.shared.clearAllLogs()

        let trailingCommaJson = """
        ```json
        {
          "status": "ready",
          "message": "Added 2 kg Potato.",
          "items": [
            {
              "itemName": "Potato",
              "quantity": 2.0,
              "unit": "kg",
              "unitPrice": 30.0,
            },
          ],
        }
        ```
        """

        let result = LLMResponseParser.parse(
            content: trailingCommaJson,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato"
        )

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.parsedItems?.count, 1)
        XCTAssertEqual(result.parsedItems?.first?.itemName, "Potato")

        let records = ParsingDiagnosticsLogger.shared.recentRecords
        guard let record = records.first else {
            XCTFail("Diagnostics record not logged for auto-rescued syntax")
            return
        }

        XCTAssertEqual(record.outcome, .autoRescued)
        XCTAssertFalse(record.isFailure)
        XCTAssertTrue(record.rootCauseAnalysis.contains("Auto-repaired corrupted JSON syntax"))
    }

    func testDiagnosticsAutoRescuesTruncatedBracesSyntaxCorruption() {
        ParsingDiagnosticsLogger.shared.clearAllLogs()

        // Truncated code fence without closing braces or closing backticks
        let truncatedJson = """
        ```json
        {
          "status": "ready",
          "message": "Added 2 kg Potato.",
          "items": [
            {
              "itemName": "Potato",
              "quantity": 2.0,
              "unit": "kg",
              "unitPrice": 30.0
        """

        let result = LLMResponseParser.parse(
            content: truncatedJson,
            catalog: sampleCatalog,
            settings: .defaultSettings,
            userInput: "2kg potato"
        )

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.parsedItems?.count, 1)
        XCTAssertEqual(result.parsedItems?.first?.itemName, "Potato")

        let records = ParsingDiagnosticsLogger.shared.recentRecords
        guard let record = records.first else {
            XCTFail("Diagnostics record not logged for auto-rescued truncated syntax")
            return
        }

        XCTAssertEqual(record.outcome, .autoRescued)
        XCTAssertFalse(record.isFailure)
        XCTAssertTrue(record.rootCauseAnalysis.contains("Auto-repaired corrupted JSON syntax"))
    }

    func testBillingSpecAndClarificationSpecDerivation() {
        let input = BillingInput(request: "2kg potato", catalogSummary: "- Potato: ₹30/kg", currencySymbol: "₹")
        let spec = BillingSpec(input: input, instructions: "Billing instructions")
        XCTAssertEqual(BillingSpec.role, "Fast retail grocery store billing assistant")
        XCTAssertEqual(spec.input.request, "2kg potato")

        let clarInput = ClarificationInput(
            userInput: "Sunflower Oil",
            pendingQuery: "oil",
            pendingQuantity: 1.0,
            pendingUnit: "L",
            candidateOptions: ["Mustard Oil", "Sunflower Oil"],
            catalogSummary: "- Sunflower Oil: ₹140/L"
        )
        let clarSpec = ClarificationSpec(input: clarInput, instructions: "Verify clarification")
        XCTAssertEqual(ClarificationSpec.role, "Guardian verifier for ambiguous grocery item clarifications")
        XCTAssertEqual(clarSpec.input.candidateOptions.count, 2)
    }

    func testMasterBillingOrchestratorClarificationVerificationAndStateTransitions() async throws {
        AgentAtomSession.testResponder = { input, _ in
            if input.contains("oil") {
                return """
                ```json
                {
                  "thought": "Ambiguous oil requested.",
                  "message": "Which oil would you like?",
                  "items": {
                    "need_clarification": {
                      "oil": {
                        "quantity": 1,
                        "unit": "L",
                        "options": ["Mustard Oil", "Sunflower Oil"]
                      }
                    }
                  }
                }
                ```
                """
            }
            return nil
        }
        defer { AgentAtomSession.testResponder = nil }

        let orchestrator = MasterBillingOrchestrator.shared
        orchestrator.resetState()

        let fullCatalog = CatalogStorageService().loadDefaultCatalog()

        // 1. Initial State with Ambiguous query "1L oil" -> transitions to .clarification
        let ambiguousMsg = try await orchestrator.process(
            userInput: "1L oil",
            conversationHistory: [],
            catalog: fullCatalog,
            settings: .defaultSettings
        )
        XCTAssertEqual(ambiguousMsg.status, .needsClarification)
        if case .clarification(let pending) = orchestrator.state {
            XCTAssertTrue(pending.candidateNames.contains("Mustard Oil"))
            XCTAssertTrue(pending.candidateNames.contains("Sunflower Oil"))
        } else {
            XCTFail("Orchestrator should be in .clarification state")
        }

        // 2. Clarification State with valid clarification reply "Sunflower Oil" -> verifies real clarification and transitions back to .initial
        let history = [
            AgentMessage(role: .user, text: "1L oil"),
            ambiguousMsg
        ]
        let resolvedMsg = try await orchestrator.process(
            userInput: "Sunflower Oil",
            conversationHistory: history,
            catalog: fullCatalog,
            settings: .defaultSettings
        )
        XCTAssertEqual(resolvedMsg.status, .ready)
        XCTAssertEqual(resolvedMsg.parsedItems?.count, 1)
        XCTAssertEqual(resolvedMsg.parsedItems?.first?.itemName, "Sunflower Oil")
        XCTAssertEqual(orchestrator.state, .initial)
    }

    func testMasterBillingOrchestratorNonClarificationFallsBackToInitialState() async throws {
        AgentAtomSession.testResponder = { input, _ in
            if input.contains("potato") {
                return """
                ```json
                {
                  "thought": "Added 2kg potato.",
                  "message": "Added 2kg Potato to the bill.",
                  "items": {
                    "verified": {
                      "Potato": {
                        "quantity": 2,
                        "unit": "kg",
                        "unit_price": 30
                      }
                    }
                  }
                }
                ```
                """
            }
            return nil
        }
        defer { AgentAtomSession.testResponder = nil }

        let orchestrator = MasterBillingOrchestrator.shared
        orchestrator.resetState()

        let fullCatalog = CatalogStorageService().loadDefaultCatalog()

        // Set orchestrator into clarification state for "oil"
        let pending = PendingClarification(
            query: "oil",
            quantity: 1.0,
            unit: "L",
            candidateNames: ["Mustard Oil", "Sunflower Oil"]
        )
        let clarifyMsg = AgentMessage(
            role: .agent,
            text: "Which oil would you like?",
            status: .needsClarification,
            pendingClarification: pending
        )

        // Customer ignores clarification and orders an entirely different item "2kg potato"
        let nonClarifyHistory = [
            AgentMessage(role: .user, text: "1L oil"),
            clarifyMsg
        ]
        let newOrderMsg = try await orchestrator.process(
            userInput: "2kg potato",
            conversationHistory: nonClarifyHistory,
            catalog: fullCatalog,
            settings: .defaultSettings
        )

        // Master orchestrator guardian detects it is NOT a real clarification,
        // falls back to initial state, and bills the new item!
        XCTAssertEqual(newOrderMsg.status, AgentResponseStatus.ready)
        XCTAssertEqual(newOrderMsg.parsedItems?.count, 1)
        XCTAssertEqual(newOrderMsg.parsedItems?.first?.itemName, "Potato")
        XCTAssertEqual(orchestrator.state, .initial)
    }

    func testDivisibleUnitAndFalseRejectionsReconciledByGuardian() {
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()
        let rawLLMOutput = """
        ```json
        {"items": {"needClarification": {"paneer": {"unit": "kg", "options": ["Paneer"], "quantity": 0.5, "reason": "Requested quantity exceeds typical unit"}}, "rejected": {"eggs": {"reason": "Requested quantity exceeds standard unit"}, "maggi": {"reason": "Requested quantity exceeds standard unit"}}, "verified": {}}, "thought": "Customer requested 500g paneer, exceeding typical 1kg unit – ambiguous item needs clarification.", "message": "Please confirm if you'd like me to resolve the paneer quantity or adjust the other quantities."}
        ```
        """

        let result = LLMResponseParser.parse(
            content: rawLLMOutput,
            catalog: fullCatalog,
            settings: .defaultSettings,
            userInput: "500g paneer, 3 eggs, aur 1 pkt maggi"
        )

        // Guardian reconciles: 0.5kg Paneer is a divisible unit, Eggs & Maggi are catalog items
        XCTAssertEqual(result.status, .ready)
        guard let items = result.parsedItems else {
            XCTFail("Parsed items should not be nil")
            return
        }
        XCTAssertEqual(items.count, 3)

        let paneer = items.first(where: { $0.itemName == "Paneer" })
        XCTAssertNotNil(paneer)
        XCTAssertEqual(paneer?.quantity, 0.5)
        XCTAssertEqual(paneer?.unit, "kg")

        let eggs = items.first(where: { $0.itemName == "Eggs" })
        XCTAssertNotNil(eggs)
        XCTAssertEqual(eggs?.quantity, 3.0)

        let maggi = items.first(where: { $0.itemName.localizedCaseInsensitiveContains("maggi") })
        XCTAssertNotNil(maggi)
        XCTAssertEqual(maggi?.quantity, 1.0)

        XCTAssertNotNil(result.billSummary)
        XCTAssertEqual(result.billSummary?.items.count, 3)
    }

    func testItemCatalogMatcherExtractQuantityAndUnit() {
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()
        guard let paneer = fullCatalog.first(where: { $0.name == "Paneer" }),
              let eggs = fullCatalog.first(where: { $0.name == "Eggs" }),
              let maggi = fullCatalog.first(where: { $0.name.contains("Maggi") }) else {
            XCTFail("Catalog items missing")
            return
        }

        let paneerExtract = ItemCatalogMatcher.extractQuantityAndUnit(for: paneer, from: "500g paneer, 3 eggs, aur 1 pkt maggi")
        XCTAssertEqual(paneerExtract.quantity, 0.5)
        XCTAssertEqual(paneerExtract.unit, "kg")

        let eggsExtract = ItemCatalogMatcher.extractQuantityAndUnit(for: eggs, from: "500g paneer, 3 eggs, aur 1 pkt maggi")
        XCTAssertEqual(eggsExtract.quantity, 3.0)

        let maggiExtract = ItemCatalogMatcher.extractQuantityAndUnit(for: maggi, from: "500g paneer, 3 eggs, aur 1 pkt maggi")
        XCTAssertEqual(maggiExtract.quantity, 1.0)
    }

    func testEndToEndVolumeDivisibilityAndUnitConversion() {
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()
        guard let mustardOil = fullCatalog.first(where: { $0.name == "Mustard Oil" }) else {
            XCTFail("Mustard oil missing from default catalog")
            return
        }

        // Test volume extraction: 500ml -> 0.5 L
        let extract = ItemCatalogMatcher.extractQuantityAndUnit(for: mustardOil, from: "500ml sarso tel")
        XCTAssertEqual(extract.quantity, 0.5)
        XCTAssertEqual(extract.unit, "L")

        // Parse volume query directly
        let json = """
        ```json
        {
          "thought": "Customer requested 500ml mustard oil.",
          "message": "Added 0.5 L Mustard Oil.",
          "items": {
            "verified": {
              "Mustard Oil": {
                "quantity": 0.5,
                "unit": "L",
                "unitPrice": 160.0
              }
            }
          }
        }
        ```
        """
        let parsed = LLMResponseParser.parse(
            content: json,
            catalog: fullCatalog,
            settings: .defaultSettings,
            userInput: "500ml sarso tel"
        )
        XCTAssertEqual(parsed.status, .ready)
        XCTAssertEqual(parsed.parsedItems?.count, 1)
        XCTAssertEqual(parsed.parsedItems?.first?.quantity, 0.5)
        XCTAssertEqual(parsed.parsedItems?.first?.unit, "L")
        XCTAssertEqual(parsed.billSummary?.grandTotal, 80.0) // 0.5 * 160 = 80
    }

    func testEndToEndColloquialMultiItemOrder() async throws {
        let orchestrator = MasterBillingOrchestrator.shared
        orchestrator.resetState()
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()

        AgentAtomSession.testResponder = { input, _ in
            if input.contains("tamatar") || input.contains("aalu") || input.contains("egg") {
                return """
                ```json
                {
                  "thought": "Parsed multi-item colloquial order.",
                  "message": "Added items to bill.",
                  "items": {
                    "verified": {
                      "Potato": { "quantity": 1.5, "unit": "kg", "unitPrice": 30.0 },
                      "Tomato": { "quantity": 0.5, "unit": "kg", "unitPrice": 40.0 },
                      "Eggs": { "quantity": 6.0, "unit": "pc", "unitPrice": 7.0 }
                    }
                  }
                }
                ```
                """
            }
            return nil
        }
        defer { AgentAtomSession.testResponder = nil }

        let result = try await orchestrator.process(
            userInput: "dedh kilo aalu, aadha kilo tamatar, aur 6 eggs",
            conversationHistory: [],
            catalog: fullCatalog,
            settings: .defaultSettings
        )

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.parsedItems?.count, 3)
        XCTAssertEqual(result.billSummary?.items.count, 3)
        // Subtotal: (1.5 * 30 = 45) + (0.5 * 40 = 20) + (6 * 7 = 42) = 107.0
        XCTAssertEqual(result.billSummary?.subtotal, 107.0)
    }

    func testEndToEndClarificationCancellationOrTopicChange() async throws {
        let orchestrator = MasterBillingOrchestrator.shared
        orchestrator.resetState()
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()

        let pending = PendingClarification(
            query: "oil",
            quantity: 1.0,
            unit: "L",
            candidateNames: ["Mustard Oil", "Sunflower Oil"]
        )
        let clarifyMsg = AgentMessage(
            role: .agent,
            text: "Which oil would you like?",
            status: .needsClarification,
            pendingClarification: pending
        )

        // Customer cancels or declines the clarification
        let history = [
            AgentMessage(role: .user, text: "1L oil"),
            clarifyMsg
        ]

        AgentAtomSession.testResponder = { _, _ in
            return """
            ```json
            {
              "thought": "Customer cancelled.",
              "message": "Order cancelled.",
              "items": { "verified": {}, "rejected": {}, "needClarification": {} }
            }
            ```
            """
        }
        defer { AgentAtomSession.testResponder = nil }

        let response = try await orchestrator.process(
            userInput: "cancel",
            conversationHistory: history,
            catalog: fullCatalog,
            settings: .defaultSettings
        )

        // Guardian resets state back to initial
        XCTAssertEqual(orchestrator.state, .initial)
    }

    func testEndToEndDiscreteItemPacketsAndPieces() {
        let fullCatalog = CatalogStorageService().loadDefaultCatalog()
        guard let maggi = fullCatalog.first(where: { $0.name.contains("Maggi") }),
              let banana = fullCatalog.first(where: { $0.name == "Banana" }) else {
            XCTFail("Missing catalog items")
            return
        }

        let maggiExtract = ItemCatalogMatcher.extractQuantityAndUnit(for: maggi, from: "2 pkts maggi aur 1 dozen kela")
        XCTAssertEqual(maggiExtract.quantity, 2.0)
        XCTAssertEqual(maggiExtract.unit, "pkt")

        let bananaExtract = ItemCatalogMatcher.extractQuantityAndUnit(for: banana, from: "2 pkts maggi aur 1 dozen kela")
        XCTAssertEqual(bananaExtract.quantity, 1.0)
        XCTAssertEqual(bananaExtract.unit, "dozen")
    }
}
